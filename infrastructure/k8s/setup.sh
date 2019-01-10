#!/usr/bin/env bash

fullpath=$(readlink --canonicalize --no-newline $BASH_SOURCE)
file_folder=$(dirname $fullpath)

# load local yaml config
# if -t was not passed we stick to the default config
TARGET_FILE=${TARGET_FILE:="$cfg__project__k8s_default_config"}
# if the target file was specified but does not exist, we fall back to the default config
TARGET_CONFIG=$(file_exists "$file_folder/$TARGET_FILE" "$file_folder/$cfg__project__k8s_default_config")
eval $(parse_yaml $TARGET_CONFIG "cfg__")

# use if set or a string argument otherwise
LOCATION=${LOCATION:=$1}

# Retrieving the OS type
OS=$(get_os_type)

if [ -z "$LOCATION" ] || [ "$LOCATION" != "local" ] && [ "$LOCATION" != "remote" ];then
	echo "usage: $0 {'local' | 'remote'}";
	exit 1
elif [ "$LOCATION" = "local" ]; then
	echo "Setting up local K8s cluster";
	# setting up minikube locally
	# premise: kvm, virtualbox or whatever we are going to use should be already installed
	# https://github.com/kubernetes/minikube/blob/master/docs/drivers.md
	# the VM driver installs at /usr/bin/docker-machine-driver-* or /usr/local/bin/docker-machine-driver-*
	drivers=(kvm kvm2 hyperkit xhyve)
	available=false
	for d in "${drivers[@]}"
	do
		if [ -f /usr/bin/docker-machine-driver-$d ] || [ -f /usr/bin/docker-machine-driver-$d ]; then
			available=true
			echo "Found the $d driver"
			break
		fi
	done

	if [ ! $available ]; then
		echo "No VM driver found, please install one first: https://github.com/kubernetes/minikube/blob/master/docs/drivers.md"
		exit 1
	fi

	command -v minikube >/dev/null 2>&1 || {
                echo >&2 "minikube not available... installing";
		latest_minikube=$(get_latest_github_release "kubernetes/minikube")
		echo  "latest minikube version available is $latest_minikube"
		curl -Lo minikube https://storage.googleapis.com/minikube/releases/$latest_minikube/minikube-linux-amd64 && chmod +x minikube && sudo cp minikube /usr/local/bin/ && rm minikube
        }

	# installing kubectl if not available
	command -v kubectl >/dev/null 2>&1 || {
		echo >&2 "kubectl not available... installing";
		# https://kubernetes.io/docs/tasks/ools/install-kubectl/#install-kubectl
		# downloading latest stable release
		curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
		# making executable and moving to bin
		chmod +x ./kubectl
		mv ./kubectl /usr/local/bin/kubectl
	}

	# starting minikube cluster if not already started (to make sure this whole script is idempotent)
	kb_status=$(minikube status | grep "host:" | awk '{print $2}' FS=': ')
	if [ -z "$kb_status" ] || [ "$kb_status" = "Stopped" ]; then
		# starting minikube
		echo "Starting minikube.."
		echo "minikube start --cpus $cfg__local__cpus --memory $cfg__local__memory --disk-size=$cfg__local__storage --vm-driver $cfg__local__vm_driver "$( ( "$cfg__local__gpu_support" = true ) && printf %s '--gpu' )
		cfg__local__mnt_data="/mnt/vda1/data/storage/"
		# in case of issues with mounting, it may be due to the vm driver (they behave differently) or more probably to a firewall issue on the host
		# https://github.com/kubernetes/minikube/issues/2379
		# https://github.com/kubernetes/minikube/issues/1548
		# please run minikube mount -v10 $root_folder/data:$cfg__local__mnt_data
		# https://kubernetes.io/docs/setup/minikube/#mounted-host-folders
		# starting registry mirror on host
		docker start registry-mirror || docker run -d --restart=always -p 5000:5000 --name registry-mirror \
		-v $PWD/registry/data/:/var/lib/registry/ \
		-v $PWD/registry/config/:/etc/docker/registry/ registry:2
		echo "starting minikube"
		minikube start \
		--cpus $cfg__local__cpus \
		--memory $cfg__local__memory \
		--disk-size=$cfg__local__storage \
		--vm-driver $cfg__local__vm_driver \
		--registry-mirror http://192.168.122.1:5000 \
		--insecure-registry http://192.168.122.1:5000 $( ( "$cfg__local__gpu_support" = true ) && printf %s '--gpu' )
		# GPU setup explained at https://github.com/kubernetes/minikube/blob/master/docs/gpu.md

		echo "Minikube VM started. Node accessible using 'minikube ssh'"
		echo "Creating data dir $cfg__local__mnt_data"
		minikube ssh "sudo mkdir -p $cfg__local__mnt_data"
		minikube ssh "sudo chown rkt:rkt $cfg__local__mnt_data"

		# enable add-ons
		# https://github.com/kubernetes/minikube/blob/master/docs/addons.md
		minikube addons enable metrics-server
		if [ ! -z "$cfg__local__gpu_support" ] && [ "$cfg__local__gpu_support" = true ]; then
			minikube addons enable nvidia-driver-installer
			minikube addons enable nvidia-gpu-device-plugin
		fi
		# create a namespace for us
		kubectl create namespace $cfg__project__k8s_namespace
	else
		echo "Minikube is already running. Enjoy!"
	fi

	# add an overlay network
	if [ ! -z "$cfg__local__use_overlay" ] && [ "$cfg__local__use_overlay" = true ]; then
		. $file_folder/overlay/setup.sh
	fi

	# installing helm client
	command -v helm >/dev/null 2>&1 || {
                echo >&2 "Helm not available... installing";
		# helm installation
		wget "https://storage.googleapis.com/kubernetes-helm/helm-v2.12.1-linux-amd64.tar.gz"
		tar -zxvf helm-v2.12.1-linux-amd64.tar.gz
		mv linux-amd64/helm /usr/local/bin/helm
	}
	# initializing helm and installing tiller on the cluster
	# https://docs.helm.sh/using_helm/
	if [[ -z $(check_if_pod_exists "tiller") ]]; then
		echo "Installing Tiller"
		kubectl -n kube-system create sa tiller
		kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
		helm init --service-account tiller --wait --tiller-connection-timeout 300
		# 300 seconds (5 mins) is the default waiting time
		# --wait : block until Tiller is running and ready to receive requests
	fi
	# wait for tiller to be up and running (minikube is not respecting --wait)
	while [[ -z $(check_if_pod_exists "tiller") || $(get_pod_status "tiller") != "Running" ]]; do
		echo "tiller not yet running, waiting..."
		sleep 1
	done

	# show where tiller was deployed
	echo "Tiller deployed as pod "$(get_pod_name "tiller")
else
	echo "Setting up infrastructure on remote K8s cluster";
fi

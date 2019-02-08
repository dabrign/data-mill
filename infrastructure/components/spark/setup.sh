#!/usr/bin/env bash

fullpath=$(readlink --canonicalize --no-newline $BASH_SOURCE)
file_folder=$(dirname $fullpath)

# load local yaml config
# if -f was given and the file exists use it, otherwise fallback to the specified component default config
COMPONENT_CONFIG=$(file_exists "$file_folder/$CONFIG_FILE" "$file_folder/$cfg__project__component_default_config")
eval $(parse_yaml $COMPONENT_CONFIG "cfg__")

# use if set or a string argument otherwise
ACTION=${ACTION:=$1}

if [ -z "$ACTION" ] || [ "$ACTION" != "install" ] && [ "$ACTION" != "delete" ];then
        echo "usage: $0 {'install' | 'delete'}";
        exit 1
elif [ "$ACTION" = "install" ]; then
	# https://github.com/GoogleCloudPlatform/spark-on-k8s-operator
	helm repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator
	helm repo update
	helm upgrade $cfg__spark__release incubator/sparkoperator \
	 --namespace $cfg__project__k8s_namespace \
	 --values $file_folder/$cfg__spark__config_file \
	 --install --force
	helm repo remove incubator
else
	helm delete $cfg__spark__release --purge
fi

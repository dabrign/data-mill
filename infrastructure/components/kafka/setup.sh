#!/usr/bin/env bash

# load component paths
eval $(get_paths)
# load local yaml config
eval $(get_component_config)

# use if set or a string argument otherwise
ACTION=${ACTION:=$1}

if [ -z "$ACTION" ] || [ "$ACTION" != "install" ] && [ "$ACTION" != "delete" ];then
        echo "usage: $0 {'install' | 'delete'}";
        exit 1
elif [ "$ACTION" = "install" ]; then
	# https://strimzi.io/quickstarts/minikube/
	# install strimzi operator
	helm repo add strimzi http://strimzi.io/charts/
	helm install strimzi/strimzi-kafka-operator --name $cfg__kafka__release --namespace $cfg__project__k8s_namespace
	latest_strimzi=$(get_latest_github_release "strimzi/strimzi-kafka-operator")
	# install kafka with operator
	curl -L https://raw.githubusercontent.com/strimzi/strimzi-kafka-operator/$latest_strimzi/examples/kafka/kafka-persistent.yaml \
	| sed -e "s/my-cluster/$cfg__kafka__release/" \
	| kubectl --namespace $cfg__project__k8s_namespace apply -f -
	helm repo remove strimzi
else
	helm delete --purge $cfg__kafka__release
	kubectl delete -f https://raw.githubusercontent.com/strimzi/strimzi-kafka-operator/$latest_strimzi/examples/kafka/kafka-persistent.yaml \
	 --namespace $cfg__project__k8s_namespace
fi

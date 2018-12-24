#!/usr/bin/env bash

fullpath=$(readlink --canonicalize --no-newline $BASH_SOURCE)
file_folder=$(dirname $fullpath)

# load local yaml config
eval $(parse_yaml $file_folder/config.yaml "cfg__")

if [ -z "$1" ] || [ "$1" != "install" ] && [ "$1" != "delete" ];then
	echo "usage: $0 {install | delete}";
	exit 1
elif [ "$1" = "install" ]; then
	random_key=$(get_random_string_key 32)
	random_secret=$(get_random_secret_key)
	echo "Starting Minio with:"
	echo "- KEY:$random_key"
	echo "- SECRET:$random_secret"
	# https://github.com/helm/charts/tree/master/stable/minio#configuration	
	#helm install --set accessKey=$random_key,secretKey=$random_secret stable/minio
	helm upgrade --install $cfg__minio__release \
	 --namespace $cfg__project__k8s_namespace \
	 -f $file_folder/$cfg__minio__config_file \
	 --set accessKey=$random_key,secretKey=$random_secret \
	 stable/minio
	unset random_key
	unset random_secret
else
	helm delete $cfg__minio__release --purge
fi

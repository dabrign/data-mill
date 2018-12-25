#!/usr/bin/env bash

fullpath=$(readlink --canonicalize --no-newline $BASH_SOURCE)
file_folder=$(dirname $fullpath)

# load local yaml config
eval $(parse_yaml $file_folder/config.yaml "cfg__")

if [ -z "$1" ] || [ "$1" != "install" ] && [ "$1" != "delete" ];then
	echo "usage: $0 {install | delete}";
	exit 1
elif [ "$1" = "install" ]; then
	# https://github.com/helm/charts/tree/master/stable/superset
	helm upgrade --install $cfg__influxdb__release \
	 --namespace $cfg__project__k8s_namespace \
	 -f $file_folder/$cfg__influxdb__config_file stable/influxdb
else
	helm delete $cfg__influxdb__release --purge
fi

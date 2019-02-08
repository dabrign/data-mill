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
	# replace release name to map to the right service
	sed -e "s/release-name/${cfg__grafana__release}/g" -e "s/k8s-namespace/${cfg__project__k8s_namespace}/g" $file_folder/${cfg__grafana__config_file/.yaml/_template.yaml} > $file_folder/$cfg__grafana__config_file

	helm upgrade $cfg__grafana__release stable/grafana \
	 --namespace $cfg__project__k8s_namespace \
	 --values $file_folder/$cfg__grafana__config_file \
	 --install --force

	rm $file_folder/$cfg__grafana__config_file
else
	helm delete $cfg__grafana__release --purge
fi

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
	helm repo add datawire https://www.getambassador.io/helm
	# https://medium.com/devopslinks/how-to-create-an-api-gateway-using-ambassador-on-kubernetes-95f181904ff7
	# https://www.getambassador.io/user-guide/helm
	# https://github.com/datawire/ambassador/tree/master/helm/ambassador
	helm repo update
	helm upgrade $cfg__ambassador__release datawire/ambassador \
	 --namespace $cfg__project__k8s_namespace \
	 --values $(get_values_file "$cfg__ambassador__config_file") \
	 --install --force --wait

	echo "Diagnostics available at http://"$(kubectl get svc -n=$cfg__project__k8s_namespace $cfg__ambassador__release | awk 'FNR > 1 { print $3 }')"/$cfg__ambassador__release/v0/diag/"
	helm repo remove datawire
else
	helm delete $cfg__ambassador__release --purge
fi

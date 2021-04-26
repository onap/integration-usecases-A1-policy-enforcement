# Install R-APPs as DCAE Microservices

DCAE NBI Dashboard API is used to deploy R-APPs.

## Install

Install all R-APPs using cli:

```
./rapps.sh deploy
```

## Uninstall

To uninstall all R-APPs using cli, issue command:

```
./rapps.sh undeploy
```

## Environment variables to Override

There are some environment variables that can be overriden when using shell scripts in this directory.

- NODE_IP

Kubernetes node ip address or hostname. By default this is resolved with another script (../scripts/k8s_get_node_ip.sh)
and that script is using kubectl for that. If you don't have kubectl installed and configured towards this particular
Kubernetes deployment, exporting this variable with your wanted value can be helpful.

- DCAE_DASHBOARD_NODEPORT

By default port 30418 is used for dcae-dashboard.

- DATABASE_PASSWORD

By default kubectl used to resolve value for this from certain ONAP database in script inputs_database_password.sh.

- BLUEPRINTS_DIR

By default 'blueprints' dir is use under this script directory. Can be replaced with absolute/relative path for the directory with the blueprint files.

Also, the list of the blueprint file name is hardcoded in the rapps.sh script:

```shell script
declare -a rapp_blueprint_files=(
    ${BLUEPRINTS_DIR}/k8s-datacollector.yaml
    ${BLUEPRINTS_DIR}/k8s-sleepingcelldetector.yaml
)
```

If new blueprint file will be added this list should be adjusted.

- DEPLOYMENT_ID_PREFIX

By default the "samsung" prefix is used.

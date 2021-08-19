#!/bin/bash
# Copyright (C) 2021 by Samsung Electronics Co., Ltd.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#     http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License

#
# Onboard R-APP blueprint and deploy R-APP as DCAE Microservice.
#
set -e

NODE_IP=${NODE_IP:-$(../scripts/k8s_get_node_ip.sh)}
DCAE_DASHBOARD_NODEPORT=${DCAE_DASHBOARD_NODEPORT:-30418}
BASE_URL=https://${NODE_IP}:${DCAE_DASHBOARD_NODEPORT}

dcae_cli(){
    local parameters=("$@")
    python -u dcae-cli.py --base_url ${BASE_URL} --operation "${parameters[@]}"
}

create_blueprint() {
    local blueprint_file_path=$1
    dcae_cli create_blueprint --blueprint_file ${blueprint_file_path}
}

delete_blueprint() {
    local blueprint_name=$1
    local blueprint_id=$(dcae_cli get_blueprint --blueprint_name ${blueprint_name} | grep typeId | cut -d '"' -f 4)
    if [[ "$blueprint_id" != "" ]]; then
        dcae_cli delete_blueprint --blueprint_id ${blueprint_id}
    else
        echo "Given blueprint '$blueprint_name' does not exist!"
    fi
}

create_deployment() {
    local blueprint_id=$1
    local deployment_id=$2
    local deployment_id_prefix=$3
    local deployment_inputs_key_value=$4
    local deployment_inputs=""
    if [[ "$deployment_inputs_key_value" != "" ]]; then
        deployment_inputs="--deployment_inputs_key_value ${deployment_inputs_key_value}"
    fi
    dcae_cli create_deployment --blueprint_id ${blueprint_id} --deployment_id ${deployment_id} --deployment_id_prefix ${deployment_id_prefix} ${deployment_inputs}
}

deploy() {
    local blueprint_file_path=$1
    local deployment_id=$2
    local deployment_id_prefix=$3
    local deployment_inputs_key_value=$4
    out=$(create_blueprint ${blueprint_file_path})
    echo "$out"
    blueprint_id=$(echo "$out" | grep typeId | cut -d ' ' -f 2)
    create_deployment ${blueprint_id} ${deployment_id} ${deployment_id_prefix} ${deployment_inputs_key_value}
}

undeploy() {
    local deployment_id=$1
    dcae_cli delete_deployment --deployment_id ${deployment_id}
}

operation=$1
case "$operation" in
    -h|--help|help|?|"")
        echo "Script usage:"
        echo "$0 deploy - Deploy Blueprint"
        echo "$0 undeploy - Undeploy deployment instantiated from blueprint"
        echo "$0 redeploy - Redeploy deployment"
        echo "$0 delete - Delete blueprint"
        echo "$0 list - List blueprints and deployments"
        echo "$0 list_blueprints - List blueprints"
        echo "$0 list_deployments - List deployments"
        echo "$0 get_deployment_inputs - List all deployment input parameters given to a deployment"
        echo "$0 get_deployment_input - List only single deployment input value with given key."
        ;;
    deploy)
        blueprint_file_path=$2
        deployment_id=$3
        deployment_id_prefix=$4
        deployment_inputs_key_value=$5
        deploy ${blueprint_file_path} ${deployment_id} ${deployment_id_prefix} ${deployment_inputs_key_value}
        ;;
    undeploy)
        undeploy $2
       ;;
    redeploy)
        blueprint_file_path=$2
        deployment_id=$3
        deployment_inputs_key_value=$4
        undeploy ${deployment_id}
        # Note that deployment_id in creation does not have yet the prefix
        # Split full deployment id in format "myprefix_mydeploymentid" to prefix and id part
        deployment_id_prefix="${deployment_id%%_*}"
        deployment_id_for_create="${deployment_id#*_}"
        deploy ${blueprint_file_path} ${deployment_id_for_create} ${deployment_id_prefix} ${deployment_inputs_key_value}
       ;;
    delete)
        blueprint_name=$2
        delete_blueprint ${blueprint_name}
        ;;
    list)
        dcae_cli list_blueprints
        dcae_cli list_deployments
        ;;
    list_blueprints)
        dcae_cli list_blueprints
        ;;
    list_deployments)
        dcae_cli list_deployments
        ;;
    get_deployment_inputs)
        deployment_id=$2
        dcae_cli get_deployment_inputs --deployment_id ${deployment_id}
        ;;
    get_deployment_input)
        deployment_id=$2
        input_key=$3
        dcae_cli get_deployment_input --deployment_id ${deployment_id} --deployment_input_key ${input_key} | tail -1
        ;;
    *)
        echo "Wrong usage, check '$0 -h'" >&2
        exit 1
        ;;
esac

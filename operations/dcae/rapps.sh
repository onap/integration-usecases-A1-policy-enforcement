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

set -e

BLUEPRINTS_DIR=${BLUEPRINTS_DIR:-blueprints}
DEPLOYMENT_ID_PREFIX=${DEPLOYMENT_ID_PREFIX:-"samsung"}

declare -a rapp_blueprint_files=(
    ${BLUEPRINTS_DIR}/k8s-datacollector.yaml
    ${BLUEPRINTS_DIR}/k8s-sleepingcelldetector.yaml
)

# Define deployment id names for rapps
declare -a rapp_deployment_ids=(
    rapp-datacollector
    rapp-sleepingcelldetector
)

exec_over_rapps() {
    local action_func=$1
    local rapp_filter=$2
    for i in "${!rapp_blueprint_files[@]}"
    do
        if [[ "${DEPLOYMENT_ID_PREFIX}_${rapp_deployment_ids[$i]}" == *"$rapp_filter"* ]]; then
            $action_func ${rapp_blueprint_files[$i]} ${rapp_deployment_ids[$i]}
        fi
    done
}

operation=$1
case "$operation" in
    -h|--help|help|?|"")
        echo "Script usage:"
        echo "$0 deploy - Deploy rapp(s)"
        echo "$0 undeploy - Undeploy rapp(s)"
        echo "$0 redeploy - Redeploy rapp(s)"
        echo "$0 list - List rapps properties"
        echo
        echo "BLUEPRINTS_DIR and DEPLOYMENT_ID_PREFIX variables can be exported to override default value."
        echo "BLUEPRINTS_DIR default value is 'blueprints'."
        echo "DEPLOYMENT_ID_PREFIX is a string prefixed to given deployment_id in the deploy operation."
        echo "In other operations prefixed form is used. DEPLOYMENT_ID_PREFIX default value is 'samsung'."
        ;;
    deploy)
        rapp_filter=$2
        # Create inputs. Currently the only input to be provided is database password and that is only
        # applicable for datacollector r-app at the moment;
        if [[ -z ${DATABASE_PASSWORD:-} ]]; then
          echo "DATABASE_PASSWORD value is missing!"
          echo "Run: "
          echo "\"kubectl get secret \`kubectl get secrets | grep mariadb-galera-db-root-password | awk '{print \$1}'\` -o jsonpath="{.data.password}" | base64 --decode\" in the ONAP k8s"
          echo "and after that export DATABASE_PASSWORD=\${command_out}"
          exit 1
        fi

        deployment_inputs="database_password=${DATABASE_PASSWORD}"
        do_deploy() {
            local blueprint_file=$1
            local deployment_id=$2
            if [[ "${deployment_id}" != "rapp-datacollector" ]]; then
                deployment_inputs=""
            fi
            ./dcae.sh deploy "${blueprint_file}" "${deployment_id}" "${DEPLOYMENT_ID_PREFIX}" "${deployment_inputs}"
        }
        exec_over_rapps do_deploy ${rapp_filter}
        ./dcae.sh list
        ;;
    undeploy)
        rapp_filter=$2
        do_undeploy() {
            local blueprint_file=$1
            local deployment_id=$2
            ./dcae.sh undeploy ${DEPLOYMENT_ID_PREFIX}_${deployment_id}
            ./dcae.sh delete $(basename ${blueprint_file} | cut -d'.' -f1)
        }
        exec_over_rapps do_undeploy ${rapp_filter}
        ./dcae.sh list
       ;;
    redeploy)
        rapp_filter=$2
        deployment_inputs_key_value=$3
        do_redeploy() {
            local blueprint_file=$1
            local deployment_id=$2
            ./dcae.sh redeploy "${blueprint_file}" "${DEPLOYMENT_ID_PREFIX}_${deployment_id}" "${deployment_inputs_key_value}"
        }
        exec_over_rapps do_redeploy ${rapp_filter}
        ./dcae.sh list
       ;;
    get_deployment_input)
        property=$2
        rapp_filter=$3
        do_input() {
            local blueprint_file=$1
            local deployment_id=$2
            local full_id=${DEPLOYMENT_ID_PREFIX}_${deployment_id}
            echo "${full_id}" "$(./dcae.sh get_deployment_input ${full_id} ${property})"
        }
        exec_over_rapps do_input ${rapp_filter}
        ;;
    *)
        echo "Wrong usage, check '$0 -h'" >&2
        exit 1
        ;;
esac

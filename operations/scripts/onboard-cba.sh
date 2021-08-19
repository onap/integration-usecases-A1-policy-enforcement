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
# Onboards CDS model into CDS runtime. CDS model package file is called CBA (CDS Model Package).
#
set -e

# Parameters
# $1 Path to cba zip file (Optional)
# $2 Kubernetes node ip   (Optional)


CBA_ZIP=${1:-../examples/vnf/vnf-simulator-for-onap-me/cds/cba/onap-me-cba.zip}
if [[ "$1" == "" ]]; then
  echo "CBA zip not provided. Using default: ${CBA_ZIP}"
fi
NODE_IP=${2:-$(../common/k8s_get_node_ip.sh)}
curl -X POST http://${NODE_IP}:30499/api/v1/blueprint-model/publish -H 'content-type: multipart/form-data' -H 'Authorization: Basic Y2NzZGthcHBzOmNjc2RrYXBwcw==' -F file=@${CBA_ZIP}

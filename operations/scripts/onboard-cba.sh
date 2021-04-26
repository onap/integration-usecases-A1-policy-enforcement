#!/bin/bash
# Copyright (C) 2019 by Samsung Electronics Co., Ltd.
#
# This software is the confidential and proprietary information of Samsung Electronics co., Ltd.
# ("Confidential Information"). You shall not disclose such Confidential Information and shall use
# it only in accordance with the terms of the license agreement you entered into with Samsung.

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

#!/bin/bash
# Copyright (C) 2018 by Samsung Electronics Co., Ltd.
#
# This software is the confidential and proprietary information of Samsung Electronics co., Ltd.
# ("Confidential Information"). You shall not disclose such Confidential Information and shall use
# it only in accordance with the terms of the license agreement you entered into with Samsung.

#
# Echo Kubernetes cluster first node's internal IP address
#
kubectl get nodes -o jsonpath='{ $.items[*].status.addresses[?(@.type=="InternalIP")].address }' | cut -d ' ' -f 1

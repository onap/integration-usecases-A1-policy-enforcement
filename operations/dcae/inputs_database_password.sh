#!/bin/bash
# Copyright (C) 2019 by Samsung Electronics Co., Ltd.
#
# This software is the confidential and proprietary information of Samsung Electronics co., Ltd.
# ("Confidential Information"). You shall not disclose such Confidential Information and shall use
# it only in accordance with the terms of the license agreement you entered into with Samsung.

export DATABASE_PASSWORD=${DATABASE_PASSWORD:-$(kubectl get secret `kubectl get secrets | grep mariadb-galera-db-root-password | awk '{print $1}'` -o jsonpath="{.data.password}" | base64 --decode)}

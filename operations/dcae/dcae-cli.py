#!/usr/bin/env python
#
# Copyright (C) 2020 by Samsung Electronics Co., Ltd.
#
# This software is the confidential and proprietary information of Samsung Electronics co., Ltd.
# ("Confidential Information"). You shall not disclose such Confidential Information and shall use
# it only in accordance with the terms of the license agreement you entered into with Samsung.

"""Cli application for ONAP DCAE Dashboard for managing DCAE Microservices.

Implements core parts of the API defined here:
https://git.onap.org/ccsdk/dashboard/tree/ccsdk-app-os/src/main/resources/swagger.json
"""
import argparse
import base64
import json
import os
import re
import sys
import time
from datetime import datetime

import requests
import yaml

try:
    from urllib.parse import quote
except ImportError:
    from urllib import pathname2url as quote

# Suppress https ignoring warning to be printed on screen
# InsecureRequestWarning: Unverified HTTPS request is being made...
requests.packages.urllib3.disable_warnings(requests.packages.urllib3.exceptions.InsecureRequestWarning)

ROOT_PATH = "/ccsdk-app/nb-api/v2"
BLUEPRINTS_URL = ROOT_PATH + "/blueprints"
DEPLOYMENTS_URL = ROOT_PATH + "/deployments"
EMPTY_CHAR = "-"

# Deployment operations (used in executions)
DEPLOYMENT_INSTALL = "install"
DEPLOYMENT_UNINSTALL = "uninstall"
DEPLOYMENT_UPDATE = "update"

USER_LOGIN = "su1234"
USER_PASSWORD = "fusion"


def get_url(postfix):
    return args.base_url.strip('/') + postfix

def read_json_file(file_path):
    with open(file_path) as f:
        return json.load(f)

def read_yaml_file(file_path):
    with open(file_path) as f:
        return yaml.safe_load(f)

def print_rows_formatted(matrix):
    """Prints 2 dimensional array data (matrix) formatted to screen.
    """
    col_width = max(len(word) for row in matrix for word in row) + 2  # padding
    for row in matrix:
        print("".join(word.ljust(col_width) for word in row))
    print


def str_2_date(_str):
    return datetime.strptime(_str, '%Y-%m-%dT%H:%M:%S.%fZ').strftime('%Y-%m-%d %H:%M:%S')


def create_filter(_filter):
    return quote(json.dumps(_filter))


def http(verb, url, params=None, body=None):
    print(verb + " to " + url)
    if args.verbose:
        if params:
            print("PARAMS: ")
            print(params)
            print
        if body:
            print("BODY: ")
            print(body)
            print

    headers = {'Authorization': "Basic " + base64_authorization_value,
               'Content-Type': 'application/json',
               'Accept': 'application/json'}

    r = s.request(verb,
                  url,
                  headers=headers,
                  params=params,
                  # accept all server TLS certs
                  verify=False,
                  json=body)

    if r.status_code != 200 and r.status_code != 202:
        print("Request params:")
        print("Headers: " + str(r.request.headers))
        print
        print("Body: " + str(r.request.body))
        print
        raise RuntimeError('Response status code: {} with message: {}'
                           .format(r.status_code, str(r.content)))
    if args.verbose:
        print("RESPONSE: ")
        print(r.json())
        print
    print("SUCCESSFUL " + verb)
    print
    return r


def list_blueprints():
    r = http('GET', get_url(BLUEPRINTS_URL))
    total_items = r.json()['totalItems']
    items = r.json()['items']
    list_headers = ['Blueprint Id', 'Blueprint Name', 'Blueprint version', 'Application/Component/Owner']
    data = [list_headers]
    for bp in items:
        application = bp.get("application", EMPTY_CHAR)
        component = bp.get("component", EMPTY_CHAR)
        row = [bp['typeId'], bp['typeName'], str(bp['typeVersion']), application + '/' + component + '/' + bp['owner']]
        data.append(row)
    # Print it
    print_rows_formatted(data)
    print("Total " + str(total_items) + " blueprints.")
    return r

def create_blueprint(body):
    r = http('POST', get_url(BLUEPRINTS_URL), body=body)
    if "error" in r.json():
        err_msg = json.loads(r.json()['error'])["message"]
        if re.match('^DCAE services of type.*are still running:.*', err_msg):
            print("Blueprint already exists and cannot update it as there are deployments related to that running. First delete deployments for this blueprint!")
        else:
            print(r.json()['error'])
        sys.exit(1)
    print("typeId: " + str(r.json()['typeId']))
    return r


def get_blueprint(blueprint_name):
    blueprint_filter = create_filter({
        "name": blueprint_name
    })
    return check_error(http('GET', get_url(BLUEPRINTS_URL) + "/?filters=" + blueprint_filter))


def delete_blueprint(blueprint_id):
    return check_error(http('DELETE', get_url(BLUEPRINTS_URL) + "/" + blueprint_id))

def list_deployments():
    r = http('GET', get_url(DEPLOYMENTS_URL))
    total_items = r.json()['totalItems']
    r_json = r.json()
    list_headers = ['Service Id', 'Created', 'Modified']
    data = [list_headers]
    if "items" in r_json:
        for dep in r_json["items"]:
            row = [dep['id'], str_2_date(dep['created_at']), str_2_date(dep['updated_at'])]
            data.append(row)
            print_rows_formatted(data)
    print("Total " + str(total_items) + " deployments.")
    return r

def get_deployment(deployment_id):
    return check_error(http('GET', get_url(DEPLOYMENTS_URL) + "/" + deployment_id))

def get_deployment_inputs(deployment_id, tenant):
    return check_error(http('GET', get_url(DEPLOYMENTS_URL) + "/" + deployment_id + "/inputs?tenant=" + tenant))

def create_deployment(body):
    return check_error(http('POST', get_url(DEPLOYMENTS_URL), body=body))

def update_deployment(deployment_id, body):
    return check_error(http('PUT', get_url(DEPLOYMENTS_URL) + "/" + deployment_id + "/update", body=body))

def delete_deployment(deployment_id, tenant):
    return check_error(http('DELETE', get_url(DEPLOYMENTS_URL) + "/" + deployment_id + "?tenant=" + tenant),
                       fail_msg="Cannot delete deployment if install still ongoing.")

def executions_status(deployment_id, tenant):
    return check_error(http('GET', get_url(DEPLOYMENTS_URL) + "/" + deployment_id + "/executions?tenant=" + tenant))

def deployment_exists(deployment_id, print_non_existence=True, fail_it=True):
    """Checks if deployment with given deployment-id exists.
    """
    r = get_deployment(deployment_id)
    exists = check_deployment_exists(deployment_id, r.json())
    msg = "Given deployment '" + deployment_id + "' " + ("does not exist!" if print_non_existence else "already/still exists!")
    if bool(print_non_existence) != bool(exists):
        # Separate checking of deployment existence is needed as API DELETE operation is success even if deployment does not exist.
        print(msg)
        if fail_it:
            sys.exit(1)
    return exists


def check_deployment_exists(deployment_id, deployments):
    """deployments is the json [{deployment}, ...] payload of get_deployment method
    """
    if not deployments:
        return False

    exists = False
    for dep in deployments:
        if "id" in dep and dep["id"] == deployment_id:
            exists = True

    return exists


def check_error(response, fail_it=True, fail_msg=""):
    if "error" in response.json():
        print(response.json()['error'])
        print(fail_msg)
        if fail_it:
            sys.exit(1)
    return response

def print_get_payload(payload):
    print(json.dumps(payload.json()['items'], indent=2))

def get_executions_items(payload, key, value=None):
    """Executions array may have e.g. following content
    [
      {
        "status": "terminated",
        "tenant_name": "default_tenant",
        "created_at": "2020-07-16T14:09:34.881Z",
        "workflow_id": "create_deployment_environment",
        "deployment_id": "dcae_k8s-datacollector",
        "id": "fb66d5f7-e957-4c75-bc11-f9ef9e2ae2ac"
      },
      {
        "status": "failed",
        "tenant_name": "default_tenant",
        "created_at": "2020-07-16T14:10:05.933Z",
        "workflow_id": "install",
        "deployment_id": "dcae_k8s-datacollector",
        "id": "75dfe2e9-929a-46d0-9a8d-06e0e435051c"
      }
    ]

    This function returns array of maps filtered (with key and optional value)
    from the given source executions array.
    """
    executions = payload.json()['items']
    results = []
    for execution in executions:
        if key in execution:
            if value:
                if execution[key] == value:
                    results.append(execution)
            else:
                results.append(execution)
    return results

class Timeout:
    def __init__(self, timeout, timeout_msg, sleep_time=2):
        self.counter = 0
        self.timeout = timeout
        self.timeout_msg = timeout_msg
        self.sleep_time = sleep_time

    def expired(self):
        if self.counter > self.timeout:
            print("Timeout " + str(self.timeout) + " seconds expired while waiting " + self.timeout_msg)
            return True
        time.sleep(int(self.sleep_time))
        self.counter += int(self.sleep_time)
        return False

def wait_deployment(deployment_id, operation, timeout=240):

    def get_workflow_id(deployment_id, operation):
        r = executions_status(deployment_id, args.tenant)
        print_get_payload(r)
        print("Get status for operation: %s" % operation)
        return get_executions_items(r, "workflow_id", operation)

    failed = False
    op_timeout = Timeout(timeout, "deployment " + deployment_id + " operation " + operation)
    while True:
        wf = get_workflow_id(deployment_id, operation)
        if wf:
            status = wf[0]["status"]
            print("Operation status is %s" % status)
            if status in ["terminated", "failed"]:
                result = "SUCCESS" if status == "terminated" else "FAILED"
                if status == "failed":
                    failed = True
                break
        if op_timeout.expired():
            failed = True
            result = "FAILED"
            break

    # For uninstall wait executions to be removed by Cloudify as it will bother re-cretion of same deployment
    # There would be also "workflow_id": "delete_deployment_environment" state we should follow, but that can be disappearing so fast
    # so better to just wait all executions are removed.
    if operation == DEPLOYMENT_UNINSTALL and not failed:
        ex_timeout = Timeout(timeout, "deployment " + deployment_id + " operation " + operation + " executions to be removed.")
        while True:
            if not get_workflow_id(deployment_id, operation):
                if not deployment_exists(args.deployment_id, print_non_existence=False, fail_it=False):
                    # Still wait a moment as deployment-handler may still have the deployment and
                    # would return "409 Conflict" in case of creating again deployment with same name.
                    time.sleep(7)
                    break
            if ex_timeout.expired():
                failed = True
                result = "FAILED"
                break

    print("Deployment " + deployment_id + " operation " + operation + " was " + result)
    if failed:
        sys.exit(1)

def append_deployment_inputs_key_values(key_values, inputs):
    pairs = key_values.split(",")
    for key_value in pairs:
        key, value = key_value.split("=", 1)
        inputs[key] = value
    return inputs

def parse_deployment_inputs(deployment_inputs, deployment_inputs_key_value):
    inputs = {}
    if deployment_inputs:
        inputs = read_json_file(deployment_inputs)
    if deployment_inputs_key_value:
        inputs = append_deployment_inputs_key_values(deployment_inputs_key_value, inputs)
    return inputs


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawTextHelpFormatter,
                                     epilog='''
Example commands:
    python dcae-cli.py --base_url https://infra:30983 --operation create_blueprint --blueprint_file my-blueprint.yaml
    python dcae-cli.py --base_url https://infra:30983 --operation create_blueprint --body_file create_blueprint.json --blueprint_file my-blueprint.yaml
    python dcae-cli.py --base_url https://infra:30983 --operation list_blueprints
    python dcae-cli.py --base_url https://infra:30983 --operation get_blueprint --blueprint_name my-blueprint
    python dcae-cli.py --base_url https://infra:30983 --operation delete_blueprint --blueprint_id bf31992b-8643-44ed-b9d1-f6f5a806e505
    python dcae-cli.py --base_url https://infra:30983 --operation create_deployment --blueprint_id bf31992b-8643-44ed-b9d1-f6f5a806e505 --deployment_id samuli-testi --deployment_inputs inputs.yaml
    python dcae-cli.py --base_url https://infra:30983 --operation list_deployments
    python dcae-cli.py --base_url https://infra:30983 --operation delete_deployment --deployment_id dcae_samuli-testi
    python dcae-cli.py --base_url https://infra:30983 --operation executions_status --deployment_id dcae_samuli-testi
    ''')
    parser.add_argument('-u', '--base_url', required=True, help='Base url of the DCAE Dashboard API (e.g. http://127.0.0.1:30228)')
    parser.add_argument('-o', '--operation', required=True,
        choices=['list_blueprints',
                 'create_blueprint',
                 'get_blueprint',
                 'delete_blueprint',
                 'list_deployments',
                 'get_deployment',
                 'get_deployment_inputs',
                 'get_deployment_input',
                 'create_deployment',
                 'update_deployment',
                 'delete_deployment',
                 'executions_status'], help='Operation to execute towards DCAE Dashboard')
    parser.add_argument('-b', '--body_file', help="""File path for the body of the DCAE Dashboard operation. Json format file
    Given as file path to a file having the main body parameters for blueprint creation as json format.

    Example:
    {
        "typeName": "my-blueprint",     # this is the blueprint name
        "typeVersion": 12345,           # this is blueprint version
        "application": "DCAE-app",      # OPTIONAL
        "component": "dcae-comp",       # OPTIONAL
        "owner": "Samsung Guy"          # Blueprint owner
    }
    Used for create_blueprint operation.
    Parameter is optional and by default following values are used:

    {
        "typeName": Filename of --blueprint_file parameter
        "typeVersion": 1,
        "application": "DCAE",
        "component": "dcae",
        "owner": "Samsung"
    }
    """)
    parser.add_argument('-bp', '--blueprint_file', help='File path for the Cloudify Blueprint file used as payload in DCAE Dashboard operation. Yaml format file')
    parser.add_argument('-id', '--blueprint_id', help='Blueprint Id (typeId) string parameter e.g. for delete_blueprint and create_deployment operations')
    parser.add_argument('-name', '--blueprint_name', help='Blueprint name string parameter given as "typeName" in --body_file when creating Blueprint. If --body_file is not given blueprint name is by default the name of the given blueprint file.')
    parser.add_argument('-tag', '--deployment_id', help='''Deployment tag / Service Id / Deployment Ref / Deployment Id.
    Many names for the identification of the deployment started from the blueprint.
    Used for create_deployment operation and for delete_deployment.
    Needs to uniquely identify deployment.
    This identification is labeled to Kubernetes resources e.g. PODs with key cfydeployment''')
    parser.add_argument('-prefix', '--deployment_id_prefix', default="samsung", help='Deployment Id Prefix is the optional component name prefixed to cfydeployment with underscore. If not given string "samsung" used by default.')
    parser.add_argument('-i', '--deployment_inputs', help='''Deployment input parameters for the Coudify blueprint.
    Given as file path to a file having input parameters as json format.
    Parameters given depends on the blueprint definition.

    Example:
    {
      "host_port": "30243",
      "service_id_name": "samsung-ves-rapp",
      "component_type_name": "samsung-rapp-service"
    }

    Used for create_deployment and update_deployment operations.
    Parameter is optional and by default no input parameters given for the blueprint.''')
    parser.add_argument('-kv', '--deployment_inputs_key_value', help='''Deployment input parameters for the Coudify blueprint.
    Same as --deployment_inputs but given on command line parameter with format of key value.

    key=value,key2=value2

    Parameters given depends on the blueprint definition.

    Example:
    "host_port=30243,service_id_name=samsung-ves-rapp,component_type_name=samsung-rapp-service"

    Used for create_deployment and update_deployment operations.
    Parameter is optional and by default no input parameters given for the blueprint.''')
    parser.add_argument('-k', '--deployment_input_key', help='''Deployment input parameter key for the Coudify blueprint.
    Key string used for the deployment input. Used in get_deployment_input operation to identify what input parameter is wanted.
    ''')
    parser.add_argument('-t', '--tenant', default='default_tenant', help='''Tenant used for Cloudify.
    Optional, if not given default value "default_tenant" is used.
    Used for create_deployment and delete_deployment operations.''')
    parser.add_argument('-v', '--verbose', action='store_true', help='Output more')
    args = parser.parse_args()

    if args.blueprint_id is None and args.operation in ['create_deployment',
                                                        'delete_blueprint']:
        parser.error("--operation " + args.operation + " requires --blueprint_id argument.")
    if args.blueprint_name is None and args.operation in ['get_blueprint', 'update_deployment']:
        parser.error("--operation " + args.operation + " requires --blueprint_name argument.")
    if args.operation == 'create_blueprint' and args.blueprint_file is None:
        parser.error("--operation create_blueprint requires --blueprint_file arguments. Note also optional --body_file can be given.")
    if args.deployment_id is None and args.operation in ['create_deployment',
                                                         'get_deployment',
                                                         'get_deployment_inputs',
                                                         'get_deployment_input',
                                                         'update_deployment',
                                                         'delete_deployment',
                                                         'executions_status']:
        parser.error("--operation " + args.operation + " requires --deployment_id argument.")
    if (args.deployment_inputs is None and args.deployment_inputs_key_value is None) and args.operation in ['update_deployment']:
        parser.error("--operation " + args.operation + " requires --deployment_inputs or --deployment_inputs_key_value argument.")
    if args.deployment_input_key is None and args.operation in ['get_deployment_input']:
        parser.error("--operation " + args.operation + " requires --deployment_input_key argument.")
    return parser.parse_args()


def get_authorization_value(user_login=USER_LOGIN, user_password=USER_PASSWORD):
    base64_bytes = base64.b64encode((user_login + ":" + user_password).encode('ascii'))
    return base64_bytes.decode('ascii')


def main():

    global args, s, base64_authorization_value
    args = parse_args()
    s = requests.Session()
    base64_authorization_value = get_authorization_value()

    if args.operation == "list_blueprints":
        list_blueprints()
    elif args.operation == "create_blueprint":
        bp_name = os.path.splitext(os.path.basename(args.blueprint_file))[0]
        body = {
            "typeName": bp_name,
            "typeVersion": 1,
            "application": "DCAE",
            "component": "dcae",
            "owner": USER_LOGIN
        }
        if args.body_file:
            body = read_json_file(args.body_file)
        blueprint = read_yaml_file(args.blueprint_file)
        # create/replace blueprint part in body
        body['blueprintTemplate'] = yaml.dump(blueprint)
        create_blueprint(body)
    elif args.operation == "get_blueprint":
        print_get_payload(get_blueprint(args.blueprint_name))
    elif args.operation == "delete_blueprint":
        delete_blueprint(args.blueprint_id)
    elif args.operation == "create_deployment":
        full_deployment_id = args.deployment_id_prefix + "_" + args.deployment_id
        deployment_exists(full_deployment_id, print_non_existence=False)
        inputs = parse_deployment_inputs(args.deployment_inputs, args.deployment_inputs_key_value)
        body = {
          # component (deployment_id_prefix) will be prefixed to Kubernetes resources
          # label key cfydeployment with underscore.
          # E.g. cfydeployment=samsung_<deployment_id>
          # where <deployment_id> is the given args.deployment_id.
          "component": args.deployment_id_prefix,
          "tag": args.deployment_id,
          "blueprintId": args.blueprint_id,
          "tenant": args.tenant,
          "inputs": inputs
        }
        create_deployment(body)
        print("DeploymentId: " + full_deployment_id)
        wait_deployment(full_deployment_id, DEPLOYMENT_INSTALL)
    elif args.operation == "list_deployments":
        list_deployments()
    elif args.operation == "get_deployment":
        deployment_exists(args.deployment_id)
        print_get_payload(get_deployment(args.deployment_id))
    elif args.operation == "get_deployment_inputs":
        deployment_exists(args.deployment_id)
        print_get_payload(get_deployment_inputs(args.deployment_id, args.tenant))
    elif args.operation == "get_deployment_input":
        deployment_exists(args.deployment_id)
        r = get_deployment_inputs(args.deployment_id, args.tenant)
        print(r.json()[0]["inputs"][args.deployment_input_key])
    elif args.operation == "update_deployment":
        deployment_exists(args.deployment_id)
        inputs = parse_deployment_inputs(args.deployment_inputs, args.deployment_inputs_key_value)
        body = {
          "component": args.deployment_id_prefix,
          "tag": args.deployment_id,
          "blueprintName": args.blueprint_name,
          "blueprintVersion": 1,
          "tenant": args.tenant,
          "inputs": inputs
        }
        update_deployment(args.deployment_id, body)
        wait_deployment(args.deployment_id, DEPLOYMENT_UPDATE)
    elif args.operation == "delete_deployment":
        if deployment_exists(args.deployment_id, fail_it=False):
            delete_deployment(args.deployment_id, args.tenant)
            wait_deployment(args.deployment_id, DEPLOYMENT_UNINSTALL)
    elif args.operation == "executions_status":
        print_get_payload(executions_status(args.deployment_id, args.tenant))
    else:
        print("No operation selected.")
        sys.exit(1)


if __name__ == '__main__':
    main()

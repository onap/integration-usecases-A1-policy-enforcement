.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. http://creativecommons.org/licenses/by/4.0
.. Copyright 2021 Samsung Electronics Co., Ltd.

.. _docs_A1_PE_PoC:

:orphan:

A1 Policy Enforcement PoC
-------------------------

Source files
~~~~~~~~~~~~
- A1 PE Simulator: `A1 Policy Enforcement Simulator code`_
- RAPPs code: `A1 Policy Enforcement rapps code`_

Description
~~~~~~~~~~~
This PoC shows automated A1 policy updates towards O-RAN Near-RT RIC based on VES events received from RAN elements and analysis done by ONAP Non-RT RIC components as R-APP (DCAE MSs).
The goal is to show how ONAP platform features can be used to implement a control loop based on Non RT RIC in demonstrated **Policy Enforcement scenario**. RAPPs should predicted that Cell 1 will go to sleep in 1 minute and all high priority UE (emergency) will be proactively switched from Cell 1 to Cell 2 (another cell in ue range).

**Policy Enforcement scenario**:

- A1 PE Simulator deployed as CNF in ONAP
- A1 PE Simulator is configured as RIC in ONAP Policy Management Service
- RAPPs are deployed in ONAP as DCAE MS (to monitor and optimize behavior of RAN)
- RIC simulates a sleeping cell behavior
- Detection of sleeping cell in A1 policy, triggers handover of emergency UEs to the next available cell

Deploying A1 PE Simulator CNF in ONAP
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
To onboard/distribute and instantiated the CNF ONAP mechanisms can be used, and this this instruction based on reference documentation for `vFirewall CNF Use Case`_

1-1 Build CNF package
.....................
To prepare the CNF csar that can be onboarded to ONAP as VSP (SDC resource), please run the mvn command in *operations/a1-pe-sim-packages* directory:

::

    cd operations/a1-pe-sim-packages
    mvn clean install

As an expected result the *operations/a1-pe-sim-packages/target/oran-sim-csar.zip* file should be created.

1-2 CNF onboarding and distribution
...................................

**<MANUAL>**

Service Creation in SDC is composed of the same steps that are performed by the most other use-cases. For reference, you can refer to `vLB use-case`_

Onboard VSP

    Remember during VSP onboard to choose “Network Package” Onboarding procedure

Create VF and Service Service -> Properties Assignment -> Choose VF (at right box):

    sdnc_artifact_name - vnf

    sdnc_model_name - a1_pe_simulator

    sdnc_model_version - 1.3.2

    controller_actor - CDS

    skip_post_instantiation_configuration - False


**<MANUAL>**

Distribute service.

Verify in SDC UI if distribution was successful. In case of any errors (sometimes SO fails on accepting CLOUD_TECHNOLOGY_SPECIFIC_ARTIFACT), try redistribution.

1-3 CNF instantiation
.....................

Postman collection setup
++++++++++++++++++++++++

For this PoC purpose the Postman collection was created to present all manual ONAP steps, so it will be clear what exactly is needed. Some of the steps, such as AAI population, are automated by Robot scripts in other ONAP demos (**./demo-k8s.sh onap init**).

Postman collection is used also to trigger instantiation using SO APIs.

Following steps are needed to setup Postman:

- Import this Postman collection (environment file is provided for reference, it's better to create own environment on your own providing variables)

  - :download:`A1 PE CNF Postman collection <files/A1-PE-CNF.postman_collection.json>`
  - :download:`A1 PE CNF Postman collection <files/A1-PE-CNF.postman_environment.json>`

- For use case debugging purposes to get Kubernetes cluster external access to SO CatalogDB (GET operations only), modify SO CatalogDB service to NodePort instead of ClusterIP. You may also create separate own NodePort if you wish, but here we have just edited directly the service with kubectl.

::

    kubectl -n onap edit svc so-catalog-db-adapter
         - .spec.type: ClusterIP
         + .spec.type: NodePort
         + .spec.ports[0].nodePort: 30120

.. note::  The port number 30120 is used in included Postman collection

- You may also want to inspect after SDC distribution if CBA has been correctly delivered to CDS. In order to do it, the relevant calls are created and described later on in this documentation, however CDS since Frankfurt doesn't expose blueprints-processor's service as NodePort. This is OPTIONAL but if you'd like to use these calls later, you need to expose service in similar way as so-catalog-db-adapter above:

::

    kubectl edit -n onap svc cds-blueprints-processor-http
          - .spec.type: ClusterIP
          + .spec.type: NodePort
          + .spec.ports[0].nodePort: 30499

.. note::  The port number 30499 is used in included Postman collection

**Postman variables:**

Most of the Postman variables are automated by Postman scripts and environment file provided, but there are few mandatory variables that need to be setup by user.

=====================  ===================
Variable               Description
---------------------  -------------------
k8s                    ONAP Kubernetes host
managed_k8s            VES host variables use by the A1 PE sim to send the ves message (use as a input param in instantiation request to SO)
service-name           name of service as defined in SDC
service-version        version of service defined in SDC (if service wasn't updated, it should be set to "1.0")
service-instance-name  name of instantiated service (if ending with -{num}, will be autoincrement for each instantiation request)
=====================  ===================

ONAP post-install steps
+++++++++++++++++++++++

In order to prepare the data in SO to properly instantiate the CNF, the following script needs to be executed:

::

    ./operations/scripts/setup_onap_for_cnf.sh ${{k8s}}


Where MASTER_IP this is IP address of our kubernetes cluster that will be used to initialized the CNF.

This script will create appropriated resources e.q:
- tenant
- cloud-region
- cloud-owner
and properly configure the k8splugin and SO.

To test this configuration you can use:

::

    Postman -> A1-PE_CNF -> [TEST] SO Catalog DB Cloud Sites

Postman execution to initialize the CNF
+++++++++++++++++++++++++++++++++++++++

**<MANUAL>**

Postman collection is automated to populate needed parameters when queries are run in correct order.
Some of queries mark as *<TEST>* are used only to verify distribution and postman variables setup.

To initialized the CNF executed appropriated requests:

::

    Postman -> A1-PE_CNF -> [STEP 1] SDC Catalog Service
    Postman -> A1-PE_CNF -> [TEST] SDC Catalog Service Metadata - to check that CNF service was found in SDC and uuid was setup properly.
    Postman -> A1-PE_CNF -> [STEP 2] SO Catalog DB Service xNFs
    Postman -> A1-PE_CNF -> [STEP 3] SO Self-Serve Service Assign & Activate
    Postman -> A1-PE_CNF -> [TEST] SO Infra Active Requests - in this request we can see the status of the CNF instantiation

After successfully instantiation we should have (from **[TEST] SO Infra Active Requests** response):

::

    {
        "requestStatus": "COMPLETE",
        "statusMessage": "Macro-Service-createInstance request was executed correctly.",
        "flowStatus": "Successfully completed all Building Blocks",
        "progress": 100,
    }

2-1 A1 PE Closed-loop - A1 policy creation
..........................................

Postman collection setup
++++++++++++++++++++++++
The separated collection was prepared to trigger and check the A1 Close-loop.

Like before, following steps are needed to setup Postman:

- Import Postman collection into Postman. Environment **A1-PE_CNF.postman_environment.json** file is provided for reference, it's better to create own environment on your own providing variables.
    - :download:`A1-PE-CLOSED-LOOP.postman_collection.json`


CNF post-instantiation steps
++++++++++++++++++++++++++++

**Register CNF as a RIC in onap-a1policymanagement**

ONAP Policy Management Service support two ways of updating configuration.

Updating configuration is needed to provide information about the new RIC which was deployed.

In our case we must provide information about the new A1 Policy Enforcement Simulator that was deployed by ONAP and PMS
will be used to periodically check the healthiness of this Simulator and be able to create new A1 Policy Instances.

1. REST request to update PMS configuration (PREFERRED)

::

    [CONFIGURE-STEP 0] Register A1 PE SIM as a Near-RT RIC
    [TEST] Check if A1 PE SIM register in ONAP-PMS

2. Register CNF as a RIC in onap-a1policymanagement

::

    kubectl edit cm onap-a1policymanagement-policy-conf

update config-map with information about A1 PE Simulator:

::

    data:
      application_configuration.json: |
        {
           "config":{
              "controller":[
                 {
                    "name":"controller1",
                    "baseUrl":"https://sdnc.onap:8443",
                    "userName":"admin",
                    "password":"Kp8bJ4SXszM0WXlhak3eHlcse2gAw84vaoGGmJvUy2U"
                 }
              ],
              "ric":[
                 {
                    "name":"ric1",
                    "baseUrl":"http://{{k8s}}:32766/v1",
                    "controller":"controller1",
                    "managedElementIds":[
                    ]
                 }
              ],
              "streams_publishes":{
                  "dmaap_publisher":{
                    "type":"message_router",
                    "dmaap_info":{
                       "topic_url":"http://message-router:3904/events/A1-POLICY-AGENT-WRITE"
                    }
                 }
              },
              "streams_subscribes":{
                 "dmaap_subscriber":{
                    "type":"message_router",
                    "dmaap_info":{
                       "topic_url":"http://message-router:3904/events/A1-POLICY-AGENT-READ/users/policy-agent?timeout=15000&limit=100"
                    }
                 }
              }
           }
        }



2. Deploy RAPPs

Build the rapps docker images from `A1 Policy Enforcement rapps code`_ by using the maven:

::

    mvn clean install -Pdocker

Deploy the RAPPs as DCAE MS by using the *operations/dcae/rapps.sh* script.
To run this script a user must know the DB password generated by oom.
To get this information, run in your ONAP kubernetes:

::

    kubectl get secret `kubectl get secrets | grep mariadb-galera-db-root-password | awk '{print $1}'` -o jsonpath="{.data.password}" | base64 --decode
    DepdDuza6%Venu[

Next use this password to deploy RAPPs

::

    export NODE_IP=${{k8s}}
    export DATABASE_PASSWORD=kf93BWV9
    ./rapps.sh deploy

The expected result is to have two DCAE MS up and working:

::

    kubectl get pods | grep rapp

Output

::

    dep-rapp-datacollector-84bcd96fc4-pf42g             1/1     Running            0          4m
    dep-rapp-sleepingcelldetector-589647c4c5-rbrw9      1/1     Running            0          4m


3. Deploy/Configure Datafile collector and PM mapper

Deploy Datafile collector and PM mapper MS by using the DCAE Dashboard or Cloudify command line.

- Datafile collector deployment: https://wiki.onap.org/pages/viewpage.action?pageId=60891239#DataFileCollector(5GUsecase)-DeploymentSteps
- PMMapper deployment: https://wiki.onap.org/pages/viewpage.action?pageId=60891174#PMMapper(5GUsecase)-DeploymentSteps


Next, update datafile configuration with feed information (where this MS should publishing uploaded files).

::

    Postman -> A1-PE-CLOSED-LOOP -> [CONFIGURE-STEP 1] Get datafile CONSUL key value
    Postman -> A1-PE-CLOSED-LOOP -> [CONFIGURE-STEP 2] Update feed DATAFILE-COLLECTOR configuration

Also updated publisher's ID and password to feed 1 of Data Router:

::

    Postman -> A1-PE-CLOSED-LOOP -> [CONFIGURE-STEP 3] Updated publisher's DMaaP feed

Without this update we have Error 403 - FORBIDDEN when trying to upload file to DR.

Subscribe PM Mapper to Data Router to receive published files:

::

    Postman -> A1-PE-CLOSED-LOOP -> [CONFIGURE-STEP 5] Subscribe PM Mapper to DMaaP feed

Response will return subscription ID, 8 in that example:

::

    {
       "suspend":false,
       "delivery":{
          "use100":true,
          "password":"demo123456!",
          "user":"dcae@dcae.onap.org",
          "url":"https://dcae-pm-mapper:8443/delivery"
       },
       "subscriber":"dcaecm",
       "groupid":29,
       "metadataOnly":false,
       "privilegedSubscriber":false,
       "follow_redirect":false,
       "decompress":true,
       "aaf_instance":"legacy",
       "links":{
          "feed":"https://dmaap-dr-prov/feed/1",
          "log":"https://dmaap-dr-prov/sublog/8",
          "self":"https://dmaap-dr-prov/subs/8"
       },
       "created_date":1634290495896,
       "decompress": true
    }


4. Update AAF permission

Before updating AAF permission the PMMapper microservice must be deploy, because during this process
:topic.org.onap.dmaap.mr.PERFORMANCE_MEASUREMENTS permission instance will be created.

Next go to AAF webconsole under https://{{k8s}}:30251/gui/cui and login as a dcae@dcae.onap.org with password demo123456!.
Execute below command:

::

    perm grant org.onap.dmaap.mr.topic :topic.org.onap.dmaap.mr.PERFORMANCE_MEASUREMENTS sub org.onap.dcae.pmPublisher

To add sub action to org.onap.dcae.pmPublisher role that dcae@dcae.onap.org user can use to read information from
*PERFORMANCE_MEASUREMENTS* topic.

Executing the A1 PE Closed-loop
+++++++++++++++++++++++++++++++

::

    Postman -> A1-PE-CLOSED-LOOP -> [TEST] Get cells - to check that A1 PE Simulator was setup correctly and is up and working
    Postman -> A1-PE-CLOSED-LOOP -> [STEP 1] Configure the policy type
    Postman -> A1-PE-CLOSED-LOOP -> [TEST] Get policy types
    Postman -> A1-PE-CLOSED-LOOP -> [TEST] RIC healthcheck
    Postman -> A1-PE-CLOSED-LOOP -> [STEP 2] Cell - start reporting

In A1-PE-CNF.postman_environment.json is define as a VARIABLES:

=====================  ===================
Variable               Description
---------------------  -------------------
reportingMethod        Enum(FILE_READY - pm bulk file reporting potion, VES - legacy mode with sending events)
cellId                 cell identifier
=====================  ===================

Before you start execution please setup proper value for **reportingMethod** and **cellId** e.g:

::

    reportingMethod -> FILE_READY
    `cellId -> Cell1

Sending the VES message for cell1 should started. To see more details about this process please check the `A1 Policy Enforcement Simulator README`_
To trigger the A1 Closed loop, we must provide UE performance information for Sleeping Cell Detector that the cell can be in the sleeping mode in the near feature.
Sleeping Cell Detector RAPP should proactively create the A1 Policy with information that user-equipments should avoid all the cells predicted as a *SLEEPING*.
More information: `Sleeping Cell Detector RAPPs README`_
To do that we can start seeding the fault ves events (with worst UE performance that the normal one)

::

    Postman -> A1-PE-CLOSED-LOOP -> [STEP 3] Cell - start sending fault values

After 1 minute we should see in the Sleeping Cell Detector RAPP logs:

::

    2021-06-25 10:05:24,320 INFO  org.onap.rapp.sleepingcelldetector.service.PolicyAgentClient : Sending policy event; URL: http://a1policymanagement:8081/policy?id=acbf542a-09e8-4113-96bf-8ff45adbf480&ric=ric1&service=rapp-sleepingcelldetector&type=1000,
     Policy: {
      "scope" : {
        "ueId" : "emergency_samsung_s10_01"
      },
      "resources" : [ {
        "cellIdList" : [ "Cell1" ],
        "preference" : "AVOID"
      } ]
    }
    2021-06-25 10:05:24,321 DEBUG org.springframework.web.client.RestTemplate : HTTP PUT http://a1policymanagement:8081/policy?id=acbf542a-09e8-4113-96bf-8ff45adbf480&ric=ric1&service=rapp-sleepingcelldetector&type=1000
    2021-06-25 10:05:24,321 DEBUG org.springframework.web.client.RestTemplate : Writing [{
      "scope" : {
        "ueId" : "emergency_samsung_s10_01"
      },
      "resources" : [ {
        "cellIdList" : [ "Cell1" ],
        "preference" : "AVOID"
      } ]
    }] as "application/json"


In the A1 PE Simulator the new policy instance should be created for each emergency UE.

::

    Postman -> A1-PE-CLOSED-LOOP -> [TEST] Get policy instances

Also emergency UE should be hand over to a new cell (in the range of those UEs).

Request

::

    curl --location --request GET 'http://${{k8s}}:32482/v1/ran/cells/Cell3'

Response:

::

    {
    "id": "Cell3",
    "latitude": 50.06,
    "longitude": 19.94,
    "connectedUserEquipments": [
        "emergency_police_01",
        "mobile_samsung_s20_02",
        "emergency_samsung_s10_01"
    ],
    "currentState": {
        "value": "ACTIVE"
    }
  }

Now the Cell1 should be in the sleeping state:

::

    {
        "id": "Cell1",
        "latitude": 50.11,
        "longitude": 19.98,
        "connectedUserEquipments": [],
        "currentState": {
            "value": "SLEEPING"
        }
    }

We can also stop sending the VES events for this cell:

::

    Postman -> A1-PE-CLOSED-LOOP -> [STEP 4] Cell - stop reporting

2-2 A1 PE Closed-loop - A1 policy deletion
..........................................

After execution all actions described `2-1 A1 PE Closed-loop - A1 policy creation`_ chapter.

To delete create A1 policy a user can send the normal ves event for *SLEEPING* cell again (Cell1 in the this example).

::

    Postman -> A1-PE-CLOSED-LOOP -> [STEP 2] Cell - start reporting

Sleeping Cell Detector should be able to recognize that the Cell1 is *ACTIVE* again and delete the A1 Policy Instance that was created.

::

    2021-06-25 10:47:44,192 DEBUG org.springframework.web.client.RestTemplate : HTTP GET http://rapp-datacollector:8087/v1/pm/events/aggregatedmetrics?slot=10&count=12&startTime=2021-06-25T10%3A45%3A44.192051Z
    2021-06-25 10:47:44,192 DEBUG org.springframework.web.client.RestTemplate : Accept=[application/json, application/*+json]
    2021-06-25 10:47:44,252 DEBUG org.springframework.web.client.RestTemplate : Response 200 OK
    2021-06-25 10:47:44,252 DEBUG org.springframework.web.client.RestTemplate : Reading to [org.onap.rapp.sleepingcelldetector.entity.pm.PMEntity]
    2021-06-25 10:47:44,252 INFO  org.onap.rapp.sleepingcelldetector.service.CellPerformanceHandler : Handle cell: Cell1 started
    2021-06-25 10:47:44,253 INFO  org.onap.rapp.sleepingcelldetector.service.PolicyAgentClient : Policy instance 4d59fcf2-9b75-4e48-8d25-0593070e04a4 remove request will be send
    2021-06-25 10:47:44,253 DEBUG org.springframework.web.client.RestTemplate : HTTP DELETE http://a1policymanagement:8081/policy?id=4d59fcf2-9b75-4e48-8d25-0593070e04a4
    2021-06-25 10:47:44,663 DEBUG org.springframework.web.client.RestTemplate : Response 204 NO_CONTENT
    2021-06-25 10:47:44,663 INFO  org.onap.rapp.sleepingcelldetector.service.PolicyInstanceManager : Policy Instances for cell Cell1 removed
    2021-06-25 10:47:44,663 INFO  org.onap.rapp.sleepingcelldetector.service.CellPerformanceHandler : Cell Cell1 is not in failed status

Known issue
~~~~~~~~~~~

`Issue SO-3467`_

ControllerExecutionBB fails because it cannot locate BB_NAME in the table named bbname_selection_reference.

As a circumvention, please execute below command:

**ONAP Gulin**:

::

    kubectl exec -it onap-mariadb-galera-0 -n onap -- bash -c '/usr/bin/mysql -uroot -p"$MYSQL_ROOT_PASSWORD" catalogdb -e "INSERT INTO bbname_selection_reference (CONTROLLER_ACTOR, SCOPE, ACTION, BB_NAME) VALUES (\"CDS\", \"*\", \"*\", \"ControllerExecutionBB\")"'


**ONAP Honolulu (and above)**:

::

    kubectl exec -it onap-mariadb-galera-0 -n onap -- bash -c '/opt/bitnami/mariadb/bin/mysql -uroot -p"$MARIADB_ROOT_PASSWORD" catalogdb -e "INSERT INTO bbname_selection_reference (CONTROLLER_ACTOR, SCOPE, ACTION, BB_NAME) VALUES (\"CDS\", \"*\", \"*\", \"ControllerExecutionBB\")"'

.. _A1 Policy Enforcement Simulator code: https://gerrit.onap.org/r/gitweb?p=integration/simulators/A1-policy-enforcement-simulator.git;a=tree;h=refs/heads/master;hb=refs/heads/master
.. _A1 Policy Enforcement rapps code: https://gerrit.onap.org/r/gitweb?p=integration/usecases/A1-policy-enforcement-r-apps.git;a=tree;h=refs/heads/master;hb=refs/heads/master
.. _vFirewall CNF Use Case: https://docs.onap.org/projects/onap-integration/en/latest/docs_vFW_CNF_CDS.html#docs-vfw-cnf-cds
.. _vLB use-case: https://wiki.onap.org/pages/viewpage.action?pageId=71838898
.. _A1 Policy Enforcement Simulator README: https://gerrit.onap.org/r/gitweb?p=integration/simulators/A1-policy-enforcement-simulator.git;a=blob;f=README.md;h=a06c0cd34567ce6c1d0ecf791670b4f298ba29ec;hb=refs/heads/master
.. _Sleeping Cell Detector RAPPs README: https://gerrit.onap.org/r/gitweb?p=integration/usecases/A1-policy-enforcement-r-apps.git;a=blob;f=sleepingcelldetector/README.md;h=b91c15a7d4ed06566b29971bcfc5db336d9766f2;hb=refs/heads/master
.. _Issue SO-3467: https://jira.onap.org/browse/SO-3467

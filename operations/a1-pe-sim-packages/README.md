# A1-PE-Simulator

A1-PE-Simulator (a1-pe-sim) is this is a  Java SpringBoot application.
This application contains docker image with shared docker volume to store the configuration.

## Build package

Following mvn command in the current directory will build a1-pe-simulator package:
`mvn clean install`

### Artifacts

After build process described above, **/target** directory should contain:

- oran-sim-cba.zip - enriched CBA package for a1-pe-sim
- oran-sim-helm.tar.gz - helm chart for a1-pe-sim
- oran-sim-csar.zip - ONAP package with embedded the *cba* and *helm chart* for a1-pe-sim and can be used to onboard CNF to ONAP

## Docker image

The a1-pe-sim is stored in dedicated repo: https://gerrit.onap.org/r/admin/repos/integration/usecases/A1-policy-enforcement-r-apps
To create docker image pull and build this repository:

```
git clone "https://gerrit.onap.org/r/integration/simulators/A1-policy-enforcement-simulator"
cd A1-policy-enforcement-simulator
mvn clean install
```

After building you should find following docker image from local repository:

```
user@machine:~/A1-policy-enforcement-simulator$ docker images | grep sim
onap/integration/simulators/a1-pe-simulator     latest      171e5843928d        41 seconds ago      187MB
```

## Run as docker

To run built docker images use `docker-compose up -d` in docker directory. You can stop it later with `docker-compose down -v` or without `-v` if you want to preserve shared volume (most likely, you don't).

## Test A1-PE-Simulator

### Manual test

Simulator part can be manually tested to be working e.g. by using curl request.

1. Get the configured cells (in *configuration/cells.json*):

curl --location --request GET 'http://localhost:9998/v1/ran/cells/'

Example response:

```json
{
  "cells": [
    {
      "id": "Cell1",
      "latitude": 50.11,
      "longitude": 19.98,
      "connectedUserEquipments": [
        "emergency_samsung_s10_01"
      ],
      "currentState": {
        "value": "INACTIVE"
      }
    },
    {
      "id": "Cell2",
      "latitude": 50.06,
      "longitude": 20.03,
      "connectedUserEquipments": [],
      "currentState": {
        "value": "INACTIVE"
      }
    },
    {
      "id": "Cell3",
      "latitude": 50.06,
      "longitude": 19.94,
      "connectedUserEquipments": [
        "emergency_police_01",
        "mobile_samsung_s20_02"
      ],
      "currentState": {
        "value": "INACTIVE"
      }
    },
    {
      "id": "Cell4",
      "latitude": 50.11,
      "longitude": 19.88,
      "connectedUserEquipments": [],
      "currentState": {
        "value": "INACTIVE"
      }
    },
    {
      "id": "Cell5",
      "latitude": 50.01,
      "longitude": 19.99,
      "connectedUserEquipments": [],
      "currentState": {
        "value": "INACTIVE"
      }
    }
  ],
  "itemsLength": 5
}
```

2. Get the configured user equipments (in *configuration/ue.json*):

curl --location --request GET 'http://localhost:9998/v1/ran/ues/'

Example response:

```json
{
  "ues": [
    {
      "id": "emergency_police_01",
      "latitude": 50.035,
      "longitude": 19.97,
      "cellId": "Cell3",
      "cellsInRange": [
          "Cell3",
          "Cell5"
      ]
    },
    {
      "id": "mobile_samsung_s20_02",
      "latitude": 50.05,
      "longitude": 19.95,
      "cellId": "Cell3",
      "cellsInRange": [
          "Cell3"
      ]
    },
    {
      "id": "emergency_samsung_s10_01",
      "latitude": 50.09,
      "longitude": 19.94,
      "cellId": "Cell1",
      "cellsInRange": [
        "Cell1",
        "Cell3",
        "Cell4"
      ]
    }
  ],
  "itemsLength": 3
}
```

3. Start sending events (based on the configuration in *configuration/vnf.config* directory). Also in *vnf.config* file, replace the vesHost=vesconsumer, vesPort=30417 with real values.

curl --location --request POST 'http://localhost:9998/v1/ran/cells/Cell1/start'

Success response:

```
VES Event sending started
```

Check A1-PE-Simulator container logs by executing command:

```shell script
 docker exec -it a1-pe-simulator tail -f log/a1-pe-simulator/application/metrics-2021-04-28.0.log
```

Example logs:

```
2021-04-28T08:47:14.758+00:00|NULL|INFO :o.o.a.service.ves.RanVesSender:send:66: Sending following VES event: {
  "event" : {
    "commonEventHeader" : {
      "version" : "4.0.1",
      "vesEventListenerVersion" : "7.0.1",
      "sourceId" : "de305d54-75b4-431b-adb2-eb6b9e546014",
      "reportingEntityName" : "ibcx0001vm002oam001",
      "startEpochMicrosec" : 1619599800000000,
      "eventId" : "measurement0000259",
      "lastEpochMicrosec" : 1619599634754559,
      "priority" : "Normal",
      "sequence" : 3,
      "sourceName" : "ibcx0001vm002ssc001",
      "domain" : "measurement",
      "eventName" : "Measurement_vIsbcMmc",
      "reportingEntityId" : "cc305d54-75b4-431b-adb2-eb6b9e541234",
      "nfcNamingCode" : "ssc",
      "nfNamingCode" : "ibcx"
    },
    "measurementFields" : {
      "measurementInterval" : 5,
      "measurementFieldsVersion" : "4.0",
      "additionalMeasurements" : [ {
        "name" : "latency",
        "hashMap" : {
          "value" : "80"
        }
      }, {
        "name" : "throughput",
        "hashMap" : {
          "value" : "60"
        }
      }, {
        "name" : "identifier",
        "hashMap" : {
          "value" : "Cell1"
        }
      }, {
        "name" : "trafficModel",
        "hashMap" : {
          "emergency_samsung_s10_01" : "33"
        }
      } ]
    }
```

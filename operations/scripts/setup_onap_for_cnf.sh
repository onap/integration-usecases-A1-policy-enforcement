#!/bin/bash
# This scripts preloads ONAP with some relevant entries required to orchestrate CNFs
# Some steps may fail if script is ran non-first time on environment so strict error checking is turned off
set +e -x
aai_curl() {
  curl -ksSL -H "X-TransactionId: $RANDOM" -H "X-FromAppId: Jenkins" -H "Content-Type: application/json" -H "Accept: application/json" \
    -H "Authorization: Basic QUFJOkFBSQ==" "$@"
}
MASTER_IP="${1:?Missing mandatory positional parameter}"

echo "Handling AAI Entries"
aai_curl -X PUT "https://${MASTER_IP}:30233/aai/v16/cloud-infrastructure/cloud-regions/cloud-region/CloudOwner/K8sRegion" \
  --data '{
      "cloud-owner": "CloudOwner",
      "cloud-region-id": "K8sRegion",
      "cloud-type": "k8s",
      "owner-defined-type": "t1",
      "cloud-region-version": "1.0",
      "complex-name": "clli1",
      "cloud-zone": "CloudZone",
      "sriov-automation": false
  }'
aai_curl -X PUT "https://${MASTER_IP}:30233/aai/v16/cloud-infrastructure/cloud-regions/cloud-region/CloudOwner/K8sRegion/vip-ipv4-address-list/${MASTER_IP}" \
  --data "{
      \"vip-ipv4-address\": \"${MASTER_IP}\"
  }"
aai_curl -X PUT "https://${MASTER_IP}:30233/aai/v16/cloud-infrastructure/cloud-regions/cloud-region/CloudOwner/K8sRegion/relationship-list/relationship" \
  --data '{
      "related-to": "complex",
      "related-link": "/aai/v16/cloud-infrastructure/complexes/complex/clli1",
      "relationship-data": [
          {
            "relationship-key": "complex.physical-location-id",
            "relationship-value": "clli1"
          }
      ]
  }'
aai_curl -X PUT "https://${MASTER_IP}:30233/aai/v16/cloud-infrastructure/cloud-regions/cloud-region/CloudOwner/K8sRegion/availability-zones/availability-zone/k8savz" \
  --data '{
      "availability-zone-name": "k8savz",
      "hypervisor-type": "k8s"
  }'
aai_curl -X PUT "https://${MASTER_IP}:30233/aai/v16/cloud-infrastructure/cloud-regions/cloud-region/CloudOwner/K8sRegion/tenants/tenant/k8stenant" \
  --data '{
      "tenant-id": "k8stenant",
      "tenant-name": "k8stenant",
      "relationship-list": {
          "relationship": [
          {
              "related-to": "service-subscription",
              "relationship-label": "org.onap.relationships.inventory.Uses",
              "related-link": "/aai/v16/business/customers/customer/Demonstration/service-subscriptions/service-subscription/vFW",
              "relationship-data": [
                  {
                      "relationship-key": "customer.global-customer-id",
                      "relationship-value": "Demonstration"
                  },
                  {
                      "relationship-key": "service-subscription.service-type",
                      "relationship-value": "vFW"
                  }
              ]
        }
        ]
      }
  }'

echo "Configuring k8splugin"
curl -ksSL -X POST "https://${MASTER_IP}:30283/api/multicloud-k8s/v1/v1/connectivity-info" \
  --header "Content-Type: multipart/form-data" \
  --form "file=@${HOME}/.kube/config" \
  --form metadata='{
    "cloud-region": "K8sRegion",
    "cloud-owner": "CloudOwner"
  }'

echo "Configuring SO"
pass=$(kubectl get "$(kubectl get secrets -o name | grep mariadb-galera-db-root-password)" \
  -o jsonpath="{.data.password}" | base64 --decode)
kubectl -n onap exec onap-mariadb-galera-0 -- \
  mysql -uroot -p"${pass}" -D catalogdb -e \
  'INSERT IGNORE INTO
    cloud_sites(ID, REGION_ID, IDENTITY_SERVICE_ID, CLOUD_VERSION, CLLI, ORCHESTRATOR)
    values("K8sRegion", "K8sRegion", "DEFAULT_KEYSTONE", "2.5", "clli1", "multicloud");'

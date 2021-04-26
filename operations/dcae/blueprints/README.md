# Blueprint files for Cloudify

Cloudify nodes types supported by ONAP Guilin are here:
https://gerrit.onap.org/r/gitweb?p=dcaegen2/platform/plugins.git;a=blob;f=k8s/k8s-node-type.yaml;h=c14623aaf528db68f6aa960a18c54c603a1f943d;hb=refs/heads/guilin

R-APP blueprints are based on node type: `dcae.nodes.ContainerizedServiceComponent`

Following properties has meanings:

- service_component_type
  This comes as a name of the POD in the Kubernetes.
- service_id
  Unique id for this DCAE service instance this component belongs to.
  This value will be applied as a tag in the registration of this component with Consul.
  It will be visible in POD ENV as SERVICE_TAGS value.

POD ENV

Environment:

- DCAE_CA_CERTPATH:        /opt/dcae/cacert/cacert.pem
- CONSUL_HOST:             consul-server.onap
- SERVICE_TAGS:            rapp-service_id
- CONFIG_BINDING_SERVICE:  config-binding-service
- CBS_CONFIG_URL:          https://config-binding-service:10443/service_component_all/s8def4b1fc2ad4c05ba635289452860ee-componenttype-rapp

POD Labels:
app=s8def4b1fc2ad4c05ba635289452860ee-componenttype-rapp  --> name of the POD without prefix
cfydeployment=samsung_samsung-rapp-1                      --> Service ID/Deployment Ref. / DeploymentId given to API when creating deployment
cfynode=rapp-cloudify-node-template                       --> Blueprint node-template definition
cfynodeinstance=rapp-cloudify-node-template_zbhke6
k8sdeployment=dep-s8def4b1fc2ad4c05ba635289452860ee-componenttype-rapp    --> Complete POD name
pod-template-hash=6cdcd77994

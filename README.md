# A1 Policy Enforcement use-case repository

Goal of this use case is to present that:

- A1-PE-Simulator can send VES events based on which a future sleeping cell can be detected
- R-APP can predict a sleeping cell
- R-APP can enforce an A1 policy for critical devices to avoid the cell for which a failure has been predicted
- R-APPs can be deployed in the DCAE Framework

Assumptions:

- R-APPs are DCAE Applications
- R-APP will provides REST API to the event store
- ONAP Policy Management Service and SDNR/A1 Adapter are used to enforce the A1 Policy
- Configuration of topology and user equipment are configured in A1-PE Simulator json file
- A1-PE Simulator is a CNF

Repository contain:

- operations/dcae - DCAE CLI that deploys RAPPs in the DCAE framework
- operations/scripts - helper scripts to support the use case

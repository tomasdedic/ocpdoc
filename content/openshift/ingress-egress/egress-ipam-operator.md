---
title: "Egress Ipam Operator"
date: 2021-03-14 
author: Tomas Dedic
description: "Instalace a použití egress ipam operatoru v prostředí Azure"
lead: ""
categories:
  - "Openshift"
tags:
  - "Egress"
---

[https://github.com/redhat-cop/egressip-ipam-operator](https://github.com/redhat-cop/egressip-ipam-operator)

## Install
Jelikož je helm chart nefunkční uděláme render ručně
```sh
git clone https://github.com/redhat-cop/egressip-ipam-operator
make manifests
make kustomize
# manifesty jsou pak ulozene v 
# egressip-ipam-operator/config/default/render
# a crd
# egressip-ipam-operator/config/crd/render
```
Z manifestu vytvorime helm chart a natemplatujeme

## Definice IPAM

> This operator has the ability to detect failed nodes and move the egressIPs these nodes were carring to other nodes.\
> However this mechanism is relatively slow (order of magnitudes is minutes), so it should be considered a self-healing mechanism.\
> Shuffling EgressIPs around is an involved process because cloud providers are hardly designed for this use case especially when VM instances are carrying several EgressIPs.\
> So we encourage users to test this process in their specific deployment as it will be certainly triggered when doing an OpenShift upgrade.\
> If you are looking for High Availability, i.e. the ability to continue to operate when a the node carrying the egressIP goes down, you have to define multiple CIDRs in the CR.\
> This way each namespace will get multiple EgressIPs enabling OpenShift to use the secondary EgressIP when the first EgressIP is not available.

### 1.Neřešíme HA, jeden nod z worker z poolu worker nodu budu držet egressIP

```yaml
# define 
apiVersion: redhatcop.redhat.io/v1alpha1
kind: EgressIPAM
metadata:
  name: egressipam-azure
spec:
  # Add fields here
  cidrAssignments:
    - labelValue: ""
      CIDR: 10.3.32.0/19 #CIDR pro worker nody
      reservedIPs: 
      - "10.3.32.4"
      - "10.3.32.5"
      - "10.3.32.6"
      - "10.3.32.7"
      - "10.3.32.8"
  topologyLabel: "node-role.kubernetes.io/worker"
  nodeSelector:
    matchLabels:
      node-role.kubernetes.io/worker: ""
---
# automaticke prideleni EgressIP
apiVersion: v1
kind: Namespace
metadata:
  name: egressipam-azure-test-1
  annotations:
    egressip-ipam-operator.redhat-cop.io/egressipam:  egressipam-azure
---
# staticke prideleni EgressIP
apiVersion: v1
kind: Namespace
metadata:
  name: egressipam-azure-test-2
  annotations:
    egressip-ipam-operator.redhat-cop.io/egressipam:  egressipam-azure
    egressip-ipam-operator.redhat-cop.io/egressips: 10.3.32.15
```
### 2. Řešíme HA, chceme aby se workload dostal ven vždy
**When a namespace has multiple egress IP addresses, if the node hosting the first egress IP address is unreachable,  
OpenShift Container Platform will automatically switch to using the next available egress IP address until the first egress IP address is reachable again.**  
```yaml
apiVersion: redhatcop.redhat.io/v1alpha1
kind: EgressIPAM
metadata:
  name: egressipam-azure
spec:
  # Add fields here
  cidrAssignments:
  # rozdelime worker nodes CIDR na 3 z kterych bume pridelovat
    - labelValue: "westeurope-1"
      CIDR: 10.3.33.0/24
    - labelValue: "westeurope-2"
      CIDR: 10.3.34.0/24
    - labelValue: "westeurope-3"
      CIDR: 10.3.35.0/24
  # rozdelime podle topology tedy westeurope-1,westeurope-2,westeurope-3
  topologyLabel: "failure-domain.beta.kubernetes.io/zone"
  nodeSelector:
    matchExpressions:
    # chceme vynechat monitoring a logging roli a nechat to pouze na workerech
       - {key: node-role.kubernetes.io/worker, operator: Exists}
       - {key: node-role.kubernetes.io/monitoring, operator: DoesNotExist}
       - {key: node-role.kubernetes.io/logging, operator: DoesNotExist}
```
```yaml
# dynamicke prideleni egressIP 
apiVersion: v1
kind: Namespace
metadata:
  name: egressipam-azure-test1
  annotations:
    egressip-ipam-operator.redhat-cop.io/egressipam:  egressipam-azure
---
apiVersion: v1
kind: Namespace
metadata:
  name: egressipam-azure-test2
  annotations:
    egressip-ipam-operator.redhat-cop.io/egressipam:  egressipam-azure

# staticke prideleni egressIP
apiVersion: v1
kind: Namespace
metadata:
  name: egressipam-azure-test1
  annotations:
    egressip-ipam-operator.redhat-cop.io/egressipam:  egressipam-azure
    egressip-ipam-operator.redhat-cop.io/egressips: 10.3.33.11,10.3.34.11,10.3.35.11
---
apiVersion: v1
kind: Namespace
metadata:
  name: egressipam-azure-test2
  annotations:
    egressip-ipam-operator.redhat-cop.io/egressipam:  egressipam-azure
    egressip-ipam-operator.redhat-cop.io/egressips: 10.3.33.12,10.3.34.12,10.3.35.12
```
test:
```sh
oc get netnamespaces|grep egressipam-azure

egressipam-azure-test1                             2555158    ["10.3.33.11","10.3.34.11","10.3.35.11"]
egressipam-azure-test2                             329355     ["10.3.33.12","10.3.34.12","10.3.35.12"]
```
```sh
oc get hostsubnets 

NAME                             HOST IP     SUBNET          EGRESS CIDRS   EGRESS IPS
oshi-worker-westeurope1-9xlhm   10.3.32.4   10.131.0.0/23                  ["10.3.33.11","10.3.33.12"]
oshi-worker-westeurope3-2tn8n   10.3.32.6   10.131.4.0/23                  ["10.3.35.12","10.3.35.11"]
oshi-worker-westeurope2-p7g6r   10.3.32.5   10.129.4.0/23                  ["10.3.34.12","10.3.34.11"]
```

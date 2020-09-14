---
title: "Node NotReady, SchedulingDisabled"
date: 2020-05-31 
author: Tomas Dedic
description: "After update node state is NotReady, SchedulingDisabled"
lead: "working"
categories:
  - "Openshift"
tags:
  - "OCP"
  - "DEBUG"
---
After upgrade to version 4.3.3 two nodes (one master and one worker) are in state NotReady. Cluster seems to be ok, but I cannot ssh into affected nodes and cannot get some debug info.
```sh
oc get co
 > machine-config stays at 4.3.0 version, and I can see
 > some ClusterOperators in degraded state

oc get events --all-namespaces -o json|jq -r '.items[]|{obj: .involvedObject.name,namespace: .involvedObject.namespace,message: .message,last: .lastTimestamp}'
 > "obj": "etcd-quorum-guard-b86557d67-qkj4n",
 > "namespace": "openshift-machine-config-operator",
 > "message": "0/6 nodes are available: 2 node(s) didn't match node selector, 2 node(s) didn't match pod affinity/anti-affinity, 2 node(s) didn't satisfy existing pods anti-affinity rules, 2 node(s) were unschedulable.",

oc describe clusteroperators machine-config
 > Unable to apply 4.3.3: timed out waiting for the condition during syncRequiredMachineConfigPools: pool master has 
 > not progressed to latest configuration: controller version mismatch for 
 > rendered-master-8e5af15cb4464a47588b474a3b025bd8 expected 
 > 5c8eeddacb4c95bbd7f95f89821208d9a1f82a2f has 2789973d61a0011415e2d019c09bbcb0f1bd3383, retrying
 # here are two rendered masters so far
 >rendered-master-8e5af15cb4464a47588b474a3b025bd8            2789973d61a0011415e2d019c09bbcb0f1bd3383
 >rendered-master-dc5e8b258ac27b72be7d8f2b9c439f3c            5c8eeddacb4c95bbd7f95f89821208d9a1f82a2f

oc get clusterversion
 > Error while reconciling 4.3.3: the cluster operator machine-config has not yet successfully rolled out
 ```
Tried to delete **worker machine in NotReady** state, new one is created (MachineSet) but just as the new one is created another one gets (node:Events) "status is now: NodeNotReady"
```sh
Generated from machineconfigdaemon
Written pending config rendered-worker-b425f9d32a4e175bdddcc584fc74f198
Generated from machineconfigdaemon
Node will reboot into config rendered-worker-b425f9d32a4e175bdddcc584fc74f198
Generated from machineconfigdaemon
In cluster upgrade to quay.io/openshift-release-dev/ocp-v4.0-art-dev@sha256:6f2788587579df093bf990268390f7f469cce47e45a7f36b04b74aa00d1dd9e0
```

Ok problem seems to be in machineconfig
```sh
oc get machineconfigpools
oc describe machineconfigpools
```
```sh
oc adm release info --commits | grep machine-config-operator
```
```sh
stern -n openshift-machine-config-operator  machine-config
```
Problem je ze update se poukousi na nod dat novou verzi machineconfigpoolu a s tim i etcd-quorum-guard, z nejakeho duvodu je nod nasledne vyrazen z poolu. Podarilo se vyresit "pauznutim" update machineconfigpoolu .Spec.Paused: true

verze machineconfigu na jednotlivych nodech:
```sh
oc get nodes -o json|jq -r '.items[].metadata.annotations|{name:.["machine.openshift.io/machine"],current:.["machineconfiguration.openshift.io/currentConfig"],desired:.["machineconfiguration.openshift.io/desiredConfig"],state:.["machineconfiguration.openshift.io/state"]}'
oc get nodes -o custom-columns='NAME:metadata.name,CURRENT:metadata.annotations.machineconfiguration\.openshift\.io/currentConfig,DESIRED:metadata.annotations.machineconfiguration\.openshift\.io/desiredConfig,STATE:metadata.annotations.machineconfiguration\.openshift\.io/state'

  {
    "name": "openshift-machine-api/poshi4-8rlc7-master-0",
    "current": "rendered-master-8e5af15cb4464a47588b474a3b025bd8",
    "desired": "rendered-master-8e5af15cb4464a47588b474a3b025bd8",
    "state": "Done"
  }
  {
    "name": "openshift-machine-api/poshi4-8rlc7-master-1",
    "current": "rendered-master-8e5af15cb4464a47588b474a3b025bd8",
    "desired": "rendered-master-8e5af15cb4464a47588b474a3b025bd8",
    "state": "Done"
  }
  {
    "name": "openshift-machine-api/poshi4-8rlc7-master-2",
    "current": "rendered-master-8e5af15cb4464a47588b474a3b025bd8",
    "desired": "rendered-master-dc5e8b258ac27b72be7d8f2b9c439f3c",
    "state": "Working"
  }
  {
    "name": "openshift-machine-api/poshi4-8rlc7-worker-westeurope1-xd9fb",
    "current": "rendered-worker-4094cbddbb77a3c9feb44f74c454d17f",
    "desired": "rendered-worker-4094cbddbb77a3c9feb44f74c454d17f",
    "state": "Done"
  }
  {
    "name": "openshift-machine-api/poshi4-8rlc7-worker-westeurope2-jnb2c",
    "current": "rendered-worker-4094cbddbb77a3c9feb44f74c454d17f",
    "desired": "rendered-worker-4094cbddbb77a3c9feb44f74c454d17f",
    "state": "Done"
  }
  {
    "name": "openshift-machine-api/poshi4-8rlc7-worker-westeurope3-sj6rj",
    "current": "rendered-worker-4094cbddbb77a3c9feb44f74c454d17f",
    "desired": "rendered-worker-4094cbddbb77a3c9feb44f74c454d17f",
    "state": "Done"
  }
 # na master-2 se nam to rozjizdi coz odpovida chybe v logu
 # jelikoz sem linej pouzijeme stern
stern -n openshift-machine-config-operator  machine-config
  > error when evicting pod "etcd-quorum-guard-b86557d67-shjhm" (will retry after 5s):
  > Cannot evict pod as it would violate the pods disruption budget.
oc get pods etcd-quorum-guard-b86557d67-shjhm -o json|jq -r '.spec.nodeName'
  > poshi4-8rlc7-master-2
```

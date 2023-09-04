## The Machine Config Operator (MCO) 
A cluster-level operator like any other operator, but it is a special one from an OpenShift Container Platform infrastructure perspective. It manages the operating system and keeps the cluster up to date and configured. Through MCO, platform administrators can configure and update systemd, cri-o/kubelet, kernel, NetworkManager, etc. on the nodes. To do so, the MCO creates a statically rendered MachineConfig file which includes the MachineConfigs for each node. It then applies that configuration to each node.
+ Machine Config Server
+ Machine Config Controller  
  This controller generates Machine Configs for pre-defined roles (master and worker) and monitors whether an existing Machine Config CR (custom resource) is modified or new Machine Config CRs are created. When the controller detects any of those events, it will generate a new rendered Machine Config object that contains all of the Machine Configs based on MachineConfigSelector from each MachineConfigPool.  
  + Template Controller
  + Update Controller
  + Render Controller
  + Kubelet Config Controller
+ Machine Config Daemon

## Machine Config Pool for INFRA nodes
By default we have two MCP: **worker** and **master**.\
Labels node-role.kubernetes.io/role can be seen in FIELD.

{{< figure src="img/image1_42.png" caption="How Machine Config Pool selects Machine Configs and Worker" >}}

```bash
# remove label worker and add infra label
oc label node <node> node-role.kubernetes.io/infra=
oc label node <node> node-role.kubernetes.io/worker-
```
This will not change the files on the node itself: the infra pool inherits from workers by default. This means that if you add a new MachineConfig to update workers, a purely infra node will still get updated. However this will mean that workloads scheduled for workers will no longer be scheduled on this node, as it no longer has the worker label.
```yaml
# create a machineconfigpool using machineconfig worker,infra and apply it to node label infra
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfigPool
metadata:
  name: infra
spec:
  machineConfigSelector:
    matchExpressions:
      - {key: machineconfiguration.openshift.io/role, operator: In, values: [worker,infra]}
  nodeSelector:
    matchLabels:
      node-role.kubernetes.io/infra: ""
  paused: false
  maxUnavailable: 1
```
```yaml
# example machineconfig just for infra node
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: infra
  name: 50-infra
spec:
```
```bash
#check operator
oc get pods -n openshift-machine-config-operator -l k8s-app=machine-config-daemon --field-selector "spec.nodeName=network01"
```
Note: a node must have a role at any given time to be properly functioning. If you have infra-only nodes, you should first relabel the node as worker and only then proceed to unlabel it from the infra role.


## Node Labels
worker nodes - generic
**dc1,dc2 tolopogy is based on mac address which is part of hostname(different in each cluster)**\
```bash
oc get nodes -o custom-columns='NAME:.metadata.name,LABELS:.metadata.labels.topology\.kubernetes\.io/zone'|grep -E "dc."
worker-00-50-56-93-06-4a   dc1
worker-00-50-56-93-11-9c   dc1
worker-00-50-56-93-18-e4   dc1
worker-00-50-56-93-7b-01   dc1
worker-00-50-56-93-80-b1   dc1
worker-00-50-56-93-c0-c7   dc1
worker-00-50-56-93-d0-51   dc1
worker-00-50-56-93-d7-d0   dc1
worker-00-50-56-93-de-39   dc1
worker-00-50-56-93-e2-94   dc1
worker-00-50-56-ac-0c-29   dc2
worker-00-50-56-ac-37-06   dc2
worker-00-50-56-ac-47-19   dc2
worker-00-50-56-ac-6b-61   dc2
worker-00-50-56-ac-6f-db   dc2
worker-00-50-56-ac-89-fe   dc2
worker-00-50-56-ac-c0-17   dc2
worker-00-50-56-ac-cc-0d   dc2
worker-00-50-56-ac-e9-ce   dc2
worker-00-50-56-ac-f0-f6   dc2

```
**worker nodes - generic**
```yaml
labels:
      kubernetes.io/hostname: worker-MACaddr
      node-role.kubernetes.io/worker: ""
      topology.kubernetes.io/zone: dc1/dc2
```

**worker nodes - ghrunners**
```yaml
labels:
  kubernetes.io/hostname: ghrunners#
  node-role.kubernetes.io/worker: ""
  role: ghrunners

taints:
- effect: NoExecute
  key: server-role
  value: ghrunners
```
**infra nodes - generic**
```yaml
labels:
  kubernetes.io/hostname: infra#
  node-role.kubernetes.io/infra: ""
  node-role.kubernetes.io/worker: "" 
  role: infra

taints:
- effect: NoExecute
  key: server-role
  value: infra
```
**infra nodes - network**
```yaml
labels:
  egressGateway: ""
  kubernetes.io/hostname: network#
  node-role.kubernetes.io/worker: ""
  role: network

taints:
- effect: NoExecute
  key: server-role
  value: network
```


## UPGRADE maxUnavailable set over PATCH Operator for worker nodes
Since we are in GITOPS env we need to patch already existed worker MCP with new .spec.maxUnavailable 

```yaml
# do this work over patch operator
oc patch --type merge machineconfigpool/<machineconfigpool> -p '{"spec":{"maxUnavailable":"<value>"}}'
```
```yaml
apiVersion: redhatcop.redhat.io/v1alpha1
kind: Patch
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "2"
    argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
  name: mcpworker-cluster
  namespace: openshift-config
spec:
  serviceAccountRef:
    name: patcher
  patches:
    apiserver-cluster:
      targetObjectRef:
        apiVersion: machineconfiguration.openshift.io/v1
        kind: MachineConfigPool
        name: worker
      patchTemplate: |
        spec:
          maxUnavailable: 10%
      patchType: application/merge-patch+json
```
## Other tolerations to respect
Routers for shared routing should be running on **network infra nodes only** so we need to change nodeSelector and tolerations
```yaml
Shared-Routers:
  nodePlacement:
    nodeSelector:
      matchLabels:
        role: network
        kubernetes.io/os: linux
        node-role.kubernetes.io/infra: ""
    tolerations:
    - key: server-role
      operator: Equal
      value: network
      effect: NoExecute
```
```

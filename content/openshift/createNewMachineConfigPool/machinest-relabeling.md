oc label node $NODE_NAME node-role.kubernetes.io/infra=

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

## Machine Config Pool

{{< figure src="img/image2_27_0.png" caption="The relationship among Machine Config Pool/Machine Configs and Worker Nodes " >}}
{{< figure src="img/image1_42.png" caption="How Machine Config Pool selects Machine Configs and Worker" >}}

```sh
# create a machineconfigpool using machineconfig worker,infra and apply it to node label infra
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfigPool
metadata:
  name: logging
spec:
  machineConfigSelector:
    matchExpressions:
      - {key: machineconfiguration.openshift.io/role, operator: In, values: [worker,logging]}
  nodeSelector:
    matchLabels:
      node-role.kubernetes.io/logging: ""
  paused: false
```
```sh
# example machineconfig just for infra node
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: logging
  name: 50-infra
spec:
```
```sh
# remove label worker and add infra label
oc label node <node> node-role.kubernetes.io/worker-
oc label node <node> node-role.kubernetes.io/logging=
```

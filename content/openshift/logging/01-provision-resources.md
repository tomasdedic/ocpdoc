# Provision resources for logging stack on OCP

Logging stack will be installed as an operator, for elasticsearch we will use dedicated node with propriate **taint**  to allow only schedule pods with defined **toleration** (part of logging stack).

## Create custom node for logging purposes
```yaml
    taints:
    - effect: NoSchedule
      key: node-role
      value: logging
```
```yaml
    labels:
        node.purpose: logging
```
In OCP 4.4.6 seems to be a problem to create only Machine resource, failing on **Error Message:  Can't find created instance**.
I dediced to create(not to look for base problem)  MachineSet with replica 1 instead. I choose size **Standard_D4S_v3 4vcpu 16GB memory** for logging dedicated node  
{{< code file="yaml/MachineSet-logging.yaml" lang="yaml" >}}

Taints and Labels can be created later on
```sh
 # taint
kubectl taint nodes toshi44-l9tcd-logging-westeurope3-nb8lf node-role=logging:NoSchedule
 # label
oc label nodes toshi44-l9tcd-logging-westeurope3-nb8lf node.purpose=logging
```
```sh
 # get all nodes taints
oc get nodes -o json|jq -r '.items[].spec.taints'
```
In case we need to remove taint "use minus convention"
```sh
kubectl taint nodes toshi44-l9tcd-logging-westeurope3-nb8lf node-role=logging:NoSchedule-
```
## Install ClusterLogging Operator and Elasticsearch Operator
[Quite a long task described on RedHat](https://docs.openshift.com/container-platform/4.4/logging/cluster-logging-deploying.html) with more informations.

Create a Namespace for the Elasticsearch Operator
{{< code file="yaml/eo-namespace.yaml" lang="yaml" >}}

Create a Namespace for the Cluster Logging Operator
{{< code file="yaml/clo-namespace.yaml" lang="yaml" >}}

Create an Operator Group for Elasticsearch operator
{{< code file="yaml/eo-operatorgroup.yaml" lang="yaml" >}}

Create a Subscription for Elasticsearch operator
{{< code file="yaml/eo-subscription.yaml" lang="yaml" >}}

Verify Operator installation, there should be an Elasticsearch Operator in each Namespace
```sh
oc get csv --all-namespaces
```
Create an Operator Group for ClusterLogging operator
{{< code file="yaml/clo-operatorgroup.yaml" lang="yaml" >}}

Create a Subscription for ClusterLogging operator
{{< code file="yaml/clo-subscription.yaml" lang="yaml" >}}
```sh
oc get csv -n openshift-logging
 # v namespace openshift-logging by se take mel objevit operator pod
oc get deploy -n openshift-logging
 # do definice container v deploy pridame toleranci uvedenou vyse
```

## Create CLusterLogging Instance CRD
The Cluster Logging Operator Custom Resource Definition (CRD) defines a complete cluster logging deployment that includes all the components of the logging stack to collect, store and visualize logs.  
For deployment we must use correct tolerations to tolerate our node taint and allow to Schedule (can be defined in CRD). Elasticsearch will run with 1 Node and ZeroRedundancy configuration.
```yaml
      tolerations:
      - key: "node-role"
        operator: "Equal"
        value: "logging"
        effect: "NoSchedule"
        #nebo
      - key: "node-role"
        operator: "Exists"
        effect: "NoSchedule"
```
For storage we will use default storageClass managed-premium class, but later I would like to migrate to azureFile SC.
Name of the instance must be "instance" otherwise cluster-logging-operator bude failovat( OCP 4.4.6).

{{< code file="yaml/ClusterLogging-CRD.yaml" lang="yaml" >}}

### Check status of logging stack
```sh
oc get pods -n openshift-logging
oc get clusterlogging instance -n openshift-logging -o yaml
oc get Elasticsearch elasticsearch -n openshift-logging -o yaml
oc get pods --selector component=elasticsearch -n openshift-logging -o name
#health status for indexes
#indices je shell script na podu
oc exec -n openshift-logging pod/elasticsearch-cdm-1godmszn-1-6f8495-vp4lw -- indices
oc get replicaSet --selector component=elasticsearch -o name -n openshift-logging
```



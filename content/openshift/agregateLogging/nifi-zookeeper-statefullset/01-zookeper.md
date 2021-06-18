# Openshift **Nifi cluster** installation
Our process is build on helm chart and heavily modified later:
+ [cetic/helm-nifi repo](https://github.com/cetic/helm-nifi)
**Helm consists of 3 subcharts, may be a little tricky to settle.**
---
+ zookeeper
+ nifi-registry
+ nifi-toolkit - for PKI

## GIT REPOSITORY

[APACHE NIFI GITHUB REPOSITORY](https://github.com/tomasdedic/apache-nifi.git)
## BASE install
Fast forward --->
```sh
helm repo add cetic https://cetic.github.io/helm-charts/
helm search repo nifi
helm install cetic/nifi

# unable to validate against any security context constraint:
# [provider restricted: .spec.securityContext.fsGroup: Invalid value: []int64{1001}:
# 1001 is not an allowed group spec.containers[0].securityContext.runAsUser: Invalid value: 1001: must be in the ranges: [1000690000, 1000699999]]

# ach openshift, namespace get uid range dynamically , and service account default cannot run at others uids then defined for namespace
oc get ns nifi -o=jsonpath='{.metadata.annotations}'|jq
{
  "openshift.io/description": "",
  "openshift.io/display-name": "",
  "openshift.io/requester": "system:serviceaccount:openshift-apiserver:openshift-apiserver-sa",
  "openshift.io/sa.scc.mcs": "s0:c26,c20",
  "openshift.io/sa.scc.supplemental-groups": "1000690000/10000",
  "openshift.io/sa.scc.uid-range": "1000690000/10000"
}

```
Remove helmchart
```sh
# uninstall helm chart
helm delete nifi
oc delete pvc -l app.kubernetes.io/instance=nifi
```
Ok we need a scc RunAsAny something like this:
[Short scc overview](/openshift/openshift-scc/)
```yaml
apiVersion: security.openshift.io/v1
metadata:
  annotations:
    kubernetes.io/description: nifi-scc provides all features of the restricted SCC but
      allows users to run with any UID and any GID.
  name: nifi-scc
allowHostDirVolumePlugin: false
allowHostIPC: false
allowHostNetwork: false
allowHostPID: false
allowHostPorts: false
allowPrivilegeEscalation: true
allowPrivilegedContainer: false
allowedCapabilities: null
defaultAddCapabilities: null
fsGroup:
  type: RunAsAny
groups: []
priority: 10
readOnlyRootFilesystem: false
requiredDropCapabilities:
- MKNOD
runAsUser:
  type: RunAsAny
seLinuxContext:
  type: MustRunAs
supplementalGroups:
  type: RunAsAny
users:
- system:serviceaccount:nifi:default #define user
volumes:
- configMap
- downwardAPI
- emptyDir
- persistentVolumeClaim
- projected
- secret
```
```sh
# ok, create scc for user default
oc get scc nifi-scc -o=jsonpath='{.users}'
> ["system:serviceaccount:nifi:default"]%

# check the pods for  UID and fsGroup
oc get pod -o jsonpath='{range .items[*]}{@.metadata.name}{" runAsUser: "}{@.spec.containers[*].securityContext.runAsUser}{" fsGroup: "}{@.spec.securityContext.fsGroup}{" seLinuxOptions: "}{@.spec.securityContext.seLinuxOptions.level}{"\n"}{end}'
# security context can be defined in pod scope or container scope
oc get pod -o jsonpath='{range .items[*]}{@.metadata.name}{" runAsUser: "}{@.spec.containers[*].securityContext.runAsUser}{@.spec.securityContext.runAsUser}{" fsGroup: "}{@.spec.securityContext.fsGroup}{" seLinuxOptions: "}{@.spec.securityContext.seLinuxOptions.level}{"\n"}{end}'

# move on, but we still have a problems, now during image pulling
oc get pods

NAME               READY   STATUS                  RESTARTS   AGE
nifi-zookeeper-0   0/1     ImagePullBackOff        0          25m
nifi-zookeeper-1   0/1     ImagePullBackOff        0          25m
nifi-zookeeper-2   0/1     ImagePullBackOff        0          25m

oc describe pods nifi-zookeeper-0|grep Failed
# ok it seems that our public repository is not whitelisted in containter registry (only one we can use)
Failed    kubelet   Failed to pull image "docker.io/bitnami/zookeeper:3.6.2-debian-10-r37": rpc error: code = Unknown desc =
                    (Mirrors also failed: [artifactory.sudlice.cz:443/docker-io/bitnami/zookeeper:3.6.2-debian-10-r37:
                    Error reading manifest 3.6.2-debian-10-r37 in artifactory.sudlice.cz:443/docker-io/bitnami/zookeeper:
                    manifest unknown: The named manifest is not known to the registry.]): docker.io/bitnami/zookeeper:3.6.2-debian-10-r37:
                    error pinging docker registry registry-1.docker.io: Get "https://registry-1.docker.io/v2/": Proxy authentication required
Failed    kubelet   Error: ErrImagePull
Failed    kubelet   Error: ImagePullBackOff
```
### Mirror registry/local repository
As a workaroud we will use Openshift internal Container Registry:
[local container registry](/openshift/uploading_container_image_to_ocp_registry/) a pak kdyžtak zažádáme o přidání repozitářů do whitelistu.

## SC pro stateFullSet Zookeper
For storage class, managed-premium SC will be used on AzureDisks.
but:
> AzureDisks cannot be created with other redundancy then LRS. Pods with PVC are strained to stay only in oneZone as nodeAffinity. VM provided in Azure has limited numbers of datadisks used as PV.
For making it as ha as possible, we will spread topology between all three availibility zones:
```sh
oc get nodes -L failure-domain.beta.kubernetes.io/zone|grep worker|awk '{print $1" "$3" "$6}'

oaz-dev-trkn8-worker-westeurope1-fxthw worker westeurope-1
oaz-dev-trkn8-worker-westeurope2-vg8lc worker westeurope-2
oaz-dev-trkn8-worker-westeurope3-wmqpz worker westeurope-3
```
```yaml
# this feature available for 1.19 kubernetes
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: "failure-domain.beta.kubernetes.io/zone"
        whenUnsatisfiable: "DoNotSchedule"
        labelSelector:
            app.kubernetes.io/name: zookeeper
```
## Zookeeper STS rolling update
Zookeeper chart use an old version of Zookeeper. Rollout for win. Change image in helm chart. Render and apply.

**Rolling update** will be used as **default** for STS
```sh
oc rollout status statefulset/nifi-zookeeper
statefulset rolling update complete 3 pods at revision nifi-zookeeper-64675fdd78...
```
```sh
#for change-cause annotation we can set annotation
#add it to helmchart
oc annotate statefulsets.apps/nifi-zookeeper kubernetes.io/change-cause="zookeeper:3.7.0-debian-10-r40"
```









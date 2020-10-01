---
title: "Instalace OCP do EXT DC v privátním rozsahu "
date:  2020-07-24
author: Tomas Dedic
description: "Install OCP disconnected with UserDefinedRouting and Proxy settings"
lead: "DEBUG"
categories:
  - "Openshift"
tags:
  - "OCP"
  - "Install"

---
### Instalace do extenze datacentra 
```sh
# remote tunnel pro proxy z proxy serveru na bastion node určený k instalaci
# ssh spider@10.88.233.244 -R3128:127.0.0.1:3128 -f -C -N
ssh <name>@<IP_bastion> -R 3128:127.0.0.1:3128 -f -C -N
export http_proxy="http://127.0.0.1:3128"
export https_proxy="http://127.0.0.1:3128"
export http_proxy="http://10.88.233.244:3128"
export https_proxy="http://10.88.233.244:3128"
export no_proxy="`echo 10.88.233.{193..206},``echo 10.88.233.{33..62},`127.0.0.1,api-int.oaz-dev.azure.csint.cz,api.oaz-dev.azure.csint.cz,etcd-0.oaz-dev.azure.csint.cz,etcd-1.oaz-dev.azure.csint.cz,etcd-2.oaz-dev.azure.csint.cz,localhost,.oaz-dev.azure.csint.cz"
```
from outside scope
```sh
proxy:
# testovaci "unofficial"proxy
  httpProxy: http://10.88.233.244:3128
  httpsProxy: http://10.88.233.244:3128
# official CSAS proxy
  httpProxy: http://ngproxy-test.csint.cz:8080
  httpsProxy: http://ngproxy-test.csint.cz:8080
# no proxy is the same
  noProxy: .cluster.local,.svc,127.0.0.1,172.30.0.0/16,api-int.oaz-dev.azure.csint.cz,etcd-0.oaz-dev.azure.csint.cz,etcd-1.oaz-dev.azure.csint.cz,etcd-2.oaz-dev.azure.csint.cz,localhost,10.88.233.192/28,10.88.233.32/27,.oaz-dev.azure.csint.cz,168.63.129.16
```
```sh
oc logs -n openshift-machine-api machine-api-controllers-796ccb744c-68qww machine-controller
```

install install-config.yaml s instalaci typu Internal

```yaml
apiVersion: v1
baseDomain: azure.csint.cz
compute:
- architecture: amd64
  hyperthreading: Enabled
  name: worker
  platform:
    azure:
      type: Standard_D4s_v3
  replicas: 3
controlPlane:
  architecture: amd64
  hyperthreading: Enabled
  name: master
  platform:
    azure:
      type: Standard_D4s_v3
  replicas: 3
metadata:
  creationTimestamp: null
  name: oaz-dev
proxy:
  httpProxy: http://10.88.233.244:3128
  httpsProxy: http://10.88.233.244:3128
  noProxy: .cluster.local,.svc,127.0.0.1,172.30.0.0/16,api-int.oaz-dev.azure.csint.cz,etcd-0.oaz-dev.azure.csint.cz,etcd-1.oaz-dev.azure.csint.cz,etcd-2.oaz-dev.azure.csint.cz,localhost,10.88.233.192/28,10.88.233.32/27,.oaz-dev.azure.csint.cz
networking:
  clusterNetwork:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  machineNetwork:
  - cidr: 10.88.232.0/23
  networkType: OpenShiftSDN
  serviceNetwork:
  - 172.30.0.0/16
platform:
  azure:
    region: westeurope
    networkResourceGroupName: oaz-test-net-rg
    virtualNetwork: oaz-test-vnet
    controlPlaneSubnet: Master2
    computeSubnet: App2
    outboundType: UserDefinedRouting
    baseDomainResourceGroupName: openshift_az-dev-shared-rg
publish: Internal
imageContentSources:
- mirrors:
  - artifactory.csin.cz/docker-quay/openshift-release-dev/ocp-release
  source: quay.io/openshift-release-dev/ocp-release
- mirrors:
  - artifactory.csin.cz/docker-quay/openshift-release-dev/ocp-v4.0-art-dev
  source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
```

Nedaří se install, jelikož nevzniknou *worker nody*.  
debug:
```sh
oc get co
oc logs -n openshift-cloud-credential-operator deploy/cloud-credential-operator
# porovnani azure-cloud-credentials pro SP
# BASH 
# oc get secret -n openshift-machine-api azure-cloud-credentials
 for i in $(oc get secret -n openshift-machine-api azure-cloud-credentials -o json|jq -r '.data |keys []')
 do
      printf '%s\t' $i:;oc get secret -n openshift-machine-api azure-cloud-credentials -o json|jq -r ".data.$i"|base64 -d;printf '\n'
 done 
# oc get secret -n kube-system azure-credentials
 for i in $(oc get secret -n kube-system azure-credentials -o json|jq -r '.data |keys []')
 do
      printf '%s\t' $i:;oc get secret -n kube-system azure-credentials -o json|jq -r ".data.$i"|base64 -d;printf '\n'
 done 

 # tyhle dva credentials by se meli rovnat
 # a meli by se rovnat s 
  ~/.azure/osServicePrincipal.json
```
V logu se nedaří nic objevit, experimentálně ověřeno že chybí grant pro SP
```sh
az ad app permission add --id "app id of service principal" \ -- api 00000002-0000-0000-c000-000000000000 \ -- api-permissions 824c81eb0e3f8-4ee6-8f6d-de7f50d565b7-Role
```
```sh
# nefunguje machine-api takze worker nody nejsou vytvoreny
# cannot access login.msonline.com
 oc logs -f -n openshift-machine-api machine-api-controllers-68d788f55c-h4mjc machine-controller
 ```
 Problém byl způsoben nemožností dostat se na Azure API, proxy se nepropisuje do všech nódů přístup k azure API byl zaříznut na VSEC GW.

 **Globálni nastaveni proxy neni propagováno do podu v namespacech openshift-\[*]**
 ```sh
 # list all proxy settings inside pods
 for i in $(crictl ps|awk '{print $1}');do crictl ps| grep $i|awk '{print $8}'; crictl exec -- $i env|grep -i http_proxy; done
 ```

+ bootstrap:
```sh
 # env
HTTP_PROXY=http://10.88.233.244:3128
NO_PROXY=.cluster.local,.oaz-dev.azure.csint.cz,.svc,10.128.0.0/14,10.88.232.0/23,10.88.233.192/28,10.88.233.32/27,127.0.0.1,168.63.129.16,169.254.169.254,172.30.0.0/16,api-int.oaz-dev.azure.csint.cz,etcd-0.oaz-dev.azure.csint.cz,etcd-1.oaz-dev.azure.csint.cz,etcd-2.oaz-dev.azure.csint.cz,localhost
HTTPS_PROXY=http://10.88.233.244:3128
 # journal logs
journalctl -b  -u release-image.service -u bootkube.service|grep -E "E[[:digit:]]{4}"
journalctl -b -f -u release-image.service -u bootkube.service
 # grep all https://
for i in $(find . -name \*.log); do cat $i|grep http; done|grep -Eo "https:\/\/[[:graph:]]*"
```

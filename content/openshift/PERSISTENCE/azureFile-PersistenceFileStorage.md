---
title: OCP v4 AzureFile persistence file storage
date: 2020-06-10 
author: Tomas Dedic
description: "AzureFile PERSISTENT FILE STORAGE"
lead: "short howto about Azure FileStorage in Openshift scope"
categories:
  - "Openshift"
tags:
  - "STATE"
toc: true
---

# OCP v4 AzureFile PERSISTENT FILE STORAGE
Our need is to use a reliable storage as default StorageClass(SC) for OCP. Main requirement is **zone redundancy** together with **security** and **reasonable management**, in ideal state **maintanance free**.

zone distribution for nodes can been seen like:
```sh
oc get nodes -o json|jq -r '.items[].metadata|.name,.["labels"]["failure-domain.beta.kubernetes.io/zone"],"\t"'

oshi4-ckvrl-master-0                 westeurope-1
oshi4-ckvrl-master-1                 westeurope-3
oshi4-ckvrl-master-2                 westeurope-2
oshi4-ckvrl-worker-westeurope1-2b7ml westeurope-1
oshi4-ckvrl-worker-westeurope2-rf2hx westeurope-2
oshi4-ckvrl-worker-westeurope3-tmmg5 westeurope-3
```

## AZURE DISKS (default)
**After installation is default SC.**  
AzureDisks cannot be created with other redundancy then LRS. Pods with PVC are strained to stay only in oneZone as nodeAffinity. VM provided in Azure has limited numbers of datadisks used as PV.

## AZURE FILES
Azure Storage Account - File is basically SMB protocol, SA is mounted with root:root 777 permissions. If you need another permissions, You have to use Blob storage.
Blob storage is supported az StorageClass in this time.  
>kubernetes.io/azure-file does not support block volume provisioning

[Azure files supports LRS,ZRS and GRS.](https://docs.openshift.com/container-platform/4.2/storage/dynamic-provisioning.html)

### AZUREFILES configuration for OCP
For use we need to create Azure StorageAccount.
> TODO: define storage account --kind BlobStorage or BlockBlobStorage
```sh
export STORAGE_ACCOUNT_NAME="oshi4ckvrljn7zx"
export LOCATION="westeurope"
export RESOURCE_GROUP_NAME="oshi4-ckvrl-rg"
 # [--kind {BlobStorage, BlockBlobStorage, FileStorage, Storage, StorageV2}]
 # [--sku {Premium_LRS, Premium_ZRS, Standard_GRS, Standard_GZRS, Standard_LRS, Standard_RAGRS, Standard_RAGZRS, Standard_ZRS}]
 az storage account create --name "${STORAGE_ACCOUNT_NAME}" --kind "StorageV2" --location "${LOCATION}" --resource-group "${RESOURCE_GROUP_NAME}" --sku "Standard_LRS"
 ```
The **persistent-volume-binder** ServiceAccount requires permissions to create and get Secrets to store the Azure storage account and keys.
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: azure-file-binder
rules:
- apiGroups: ['']
  resources: ['secrets']
  verbs:     ['get','create']
```

add cluster role to service account:
```sh
oc adm policy add-cluster-role-to-user azure-file-binder system:serviceaccount:kube-system:persistent-volume-binder
```
create secret:
```sh
oc -n kube-system create secret generic oshi4ckvrljn7zx-storage --from-literal=azurestorageaccountname= oshi4ckvrljn7zx --from-literal=azurestorageaccountkey=${accountkey}
```
storage class:
```yaml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: azure-file-ZRS
provisioner: kubernetes.io/azure-file
mountOptions:
  - dir_mode=0775
  - file_mode=0775
  - uid=1000
  - gid=1000
  - mfsymlinks
  - nobrl
  - cache=none
  - noperm
parameters:
  location: westeurope
  #skuName: Standard_LRS
  skuName: Standard_ZRS
  storageAccount: oshi4ckvrljn7zx
reclaimPolicy: Delete
volumeBindingMode: Immediate
```
MountOptions is big issue here, mainly **noperm** directive, some containers failed when RUN command comes with chmod for a file. Noperm issue is a solution, on the other hand security is overriden.

Pokud chceme storage class udelat jako default tak je potreba upravit anotaci jako
```yaml
storageclass.kubernetes.io/is-default-class true
```
pozn: pokud uz je PVC vytvoren a ja dodatecne upravim mount parametry v SC tak se to nepropise, nejspis by to slo upravit na urovni PODu ale to sem netestoval

PV claim pak udelame nasledovne:
```yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: busyboxazurefile-1
  namespace: bitbucket
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: azure-file-zrs
  volumeMode: Filesystem
status:
  accessModes:
    - ReadWriteOnce
  capacity:
    storage: 10Gi
```
a pod nadefinujeme jako:
```yaml
---
apiVersion: apps/v1beta1
kind: Deployment
spec:
    spec:
      containers:
          volumeMounts:
            - name: busyboxazurefile-1
              mountPath: /var/busyboxazurefile
      volumes:
        - name: busyboxazurefile-1
          persistentVolumeClaim:
            claimName: busyboxazurefile-1
```

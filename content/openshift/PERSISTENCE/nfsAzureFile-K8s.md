---
title: "NFS from AzureFile to OCP, usage in STS"
date: 2021-04-20
author: Tomas Dedic
description: "AzureFile NFS vs Openshift"
lead: "working"
categories:
  - "Openshift"
tags:
  - "STATE"
toc: true
---
## Azure Storage Account
Follow steps on Azure and enable NFS on storageAccount  
**With NFS server enabled we need a provisioner, Openshift has no dynamic NFS provisioner (-OMG-).**  
For now I will step further and skip **dynamic Persistence store definition** and all PV will be created in advance.

## BASE usage
{{< code file=yaml/pv.yaml lang="yaml" >}}
{{< code file=yaml/pvc.yaml lang="yaml" >}}

## STS usage
STS is little tricky.  
StatefulSet will create it's own PersistentVolumeClaim for each pod so you don't have to create one yourself. A PersistentVolume and a PersistentVolumeClaim will bind exclusively one to one. Your PVC is binding to your volume so any PVCs created by the StatefulSet can't bind to your volume so it won't be used.

In your case your PersistentVolume and the StatefulSet below should do the trick. Make sure to delete the PersistentVolumeClaim you created so that it's not bound to your PersistentVolume. Also, make sure the storage class name is set properly below on your PV and in volumeClaimTemplates on your StatefulSet below or the PVC made by the StatefulSet may not bind to your volume.

{{< code file=yaml/storageclass.yaml lang="yaml" >}}
{{< code file="yaml/sts-pv.yaml" lang="yaml" >}}
{{< code file="yaml/sts.yaml" lang="yaml" >}}

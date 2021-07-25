
Ok my curent problem is to make a new Openshift cluster instalation. Main reason is that I need to move cluster to newly created subnet.  
But I need to transfer all my PV (azure disk) as well.
## PV decomposition with STS perspective
We are using PV with azure-disk storageClass using Premium SSD LRS SKU, it means we are not Zone redundant. In fact every our disk can only failover into nodes in same zone.
```yaml
➤ oc get sc managed-premium -o yaml|neat
allowVolumeExpansion: true
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
  name: managed-premium
parameters:
  kind: Managed
  storageaccounttype: Premium_LRS
provisioner: kubernetes.io/azure-disk
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
```
One of our PV for example. Interesting part is **nodeAffinity** which makes this PV only be possible in **westeurope-2**
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  annotations:
    pv.kubernetes.io/bound-by-controller: "yes"
    pv.kubernetes.io/provisioned-by: kubernetes.io/azure-disk
    volumehelper.VolumeDynamicallyCreatedByKey: azure-disk-dynamic-provisioner
  labels:
    failure-domain.beta.kubernetes.io/region: westeurope
    failure-domain.beta.kubernetes.io/zone: westeurope-2
  name: pvc-ec964dbb-f199-4f47-a382-7ce122c6f5c2
spec:
  accessModes:
  - ReadWriteOnce
  azureDisk:
    cachingMode: ReadOnly
    diskName: oaz-dev-rz4kf-dynamic-pvc-ec964dbb-f199-4f47-a382-7ce122c6f5c2
    diskURI: /subscriptions/d0c32b5f-c345-4bec-a129-bbc01fe24097/resourceGroups/oaz-dev-rz4kf-rg/providers/Microsoft.Compute/disks/oaz-dev-rz4kf-dynamic-pvc-ec964dbb-f199-4f47-a382-7ce122c6f5c2
    kind: Managed
  capacity:
    storage: 50Gi
  claimRef:
    apiVersion: v1
    kind: PersistentVolumeClaim
    name: nifidata-nifi-1
    namespace: monolog-nifi
    resourceVersion: "64316423"
    uid: ec964dbb-f199-4f47-a382-7ce122c6f5c2
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: failure-domain.beta.kubernetes.io/region
          operator: In
          values:
          - westeurope
        - key: failure-domain.beta.kubernetes.io/zone
          operator: In
          values:
          - westeurope-2
  persistentVolumeReclaimPolicy: Delete
  storageClassName: managed-premium
```
And our STS referencing PV by PersistentVolumeClaim.  
Take a closer look on field **name: nifidata** for volumeClaimTemplate and **claimRef** in PersistentVolume definition. These two values must match (volumeClaimTemplate will create PVC with **${name}-${pod-name}-${podreplica_starting_from_zero}**.
>A PVC to PV binding is a one-to-one mapping, using a ClaimRef which is a bi-directional binding between the PersistentVolume and the PersistentVolumeClaim.
```yaml
  volumeClaimTemplates:
  - apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      creationTimestamp: null
      name: nifidata
    spec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 50Gi
      storageClassName: managed-premium
      volumeMode: Filesystem
```
PVC definition from template
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  annotations:
    pv.kubernetes.io/bind-completed: "yes"
    pv.kubernetes.io/bound-by-controller: "yes"
    volume.beta.kubernetes.io/storage-provisioner: kubernetes.io/azure-disk
    volume.kubernetes.io/selected-node: oaz-dev-rz4kf-worker-westeurope2-7bfkx
  labels:
    app: nifi
    release: nifi
  name: nifidata-nifi-1
  namespace: monolog-nifi
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 50Gi
  storageClassName: managed-premium
  volumeName: pvc-ec964dbb-f199-4f47-a382-7ce122c6f5c2
```
**But keep in mind, in our case PV are dynamically created when PVC ask for them (storageClass), and we need to reference ones already exists (moved from an old cluster)**   
**Value volumeName is dynamically assigned during creation after PVC will find matching PV.**
It means we will need to create PV with modified values in advance, mainly ClaimRef need to be set and also we need to check wheather controller will be able to modify/delete disks created manually on Azure.

## Creating SnapShot on AzureDisk and recover as a disk
From AzureDisk in cluster create a snapshot to some temporary RG, do not use the same RG as Openshift is installed. During cluster destroy process, RG will be automatically deleted.  
Afterwards create a disk from snapshot into RG of newly installed Openshift
{{< figure src="img/snapshottodisk.png" caption="disk created from snapshot - unbound" >}}

## Create PV referencing our newly, from snapshot, created disk:  
> maybe some annotations should be removed, but I didn't find out a reason to do so. For simplier transfer of PV, it seems to me ok to keep already existed annotations

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  annotations:
    pv.kubernetes.io/bound-by-controller: "yes"
    pv.kubernetes.io/provisioned-by: kubernetes.io/azure-disk
    volumehelper.VolumeDynamicallyCreatedByKey: azure-disk-dynamic-provisioner
  labels:
    failure-domain.beta.kubernetes.io/region: westeurope
    failure-domain.beta.kubernetes.io/zone: westeurope-2
  name: pvc-recover
spec:
  accessModes:
  - ReadWriteOnce
  azureDisk:
    cachingMode: ReadOnly
    diskName: oaz-dev-rz4kf-dynamic-pvc-ec964dbb-f199-4f47-a382-7ce122c6f5c2-vol2
    diskURI: /subscriptions/d0c32b5f-c345-4bec-a129-bbc01fe24097/resourceGroups/oaz-dev-rz4kf-rg/providers/Microsoft.Compute/disks/oaz-dev-rz4kf-dynamic-pvc-ec964dbb-f199-4f47-a382-7ce122c6f5c2-vol2
    kind: Managed
  capacity:
    storage: 50Gi
  claimRef:
    apiVersion: v1
    kind: PersistentVolumeClaim
    name: bababa-bababa-0
    namespace: blaster
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: failure-domain.beta.kubernetes.io/region
          operator: In
          values:
          - westeurope
        - key: failure-domain.beta.kubernetes.io/zone
          operator: In
          values:
          - westeurope-2
  persistentVolumeReclaimPolicy: Delete
  storageClassName: managed-premium
```
it means, we need only to change or keep eye on following fields
```yaml
diskName: oaz-dev-rz4kf-dynamic-pvc-ec964dbb-f199-4f47-a382-7ce122c6f5c2-vol2
diskURI: /subscriptions/d0c32b5f-c345-4bec-a129-bbc01fe24097/resourceGroups/oaz-dev-rz4kf-rg/providers/Microsoft.Compute/disks/oaz-dev-rz4kf-dynamic-pvc-ec964dbb-f199-4f47-a382-7ce122c6f5c2-vol2
claimRef:
```
**STS** is able to reference PV by PVCtemplate matching **claimRef**:
```sh
➤ oc describe pod bababa-0 |grep Events -A4
Events:
  Type    Reason                  Age    From                     Message
  ----    ------                  ----   ----                     -------
  Normal  Scheduled               7m33s  default-scheduler        Successfully assigned blaster/bababa-0 to oaz-dev-rz4kf-worker-westeurope2-7bfkx
  Normal  SuccessfulAttachVolume  7m     attachdetach-controller  AttachVolume.Attach succeeded for volume "pvc-recover"
```

**as tested, Controller will be able to delete PV and underlaying AzureDisk (in case reclaimPolicy is Delete)**

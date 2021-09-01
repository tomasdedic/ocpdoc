---
title: "State/Persistence - Volumes/PV/PVC/SC/STS"
date: 2021-08-18
author: Tomas Dedic
description: "Desc"
lead: "workshop"
toc: true
categories:
  - "wotw"
---
{{< figure src="yaml-openshift.png" caption="YAML-vs-JSON" >}}
## 1. Volumes
[https://kubernetes.io/docs/concepts/storage/volumes/](https://kubernetes.io/docs/concepts/storage/volumes/)  
V podstatě jde o přímé namountování volumu na pod.  
**Asi nejpotřebnější části jsou:**  
- [configmap](https://kubernetes.io/docs/concepts/storage/volumes/#configmap)
- [secret](https://kubernetes.io/docs/concepts/storage/volumes/#secret)
- [emptydir](https://kubernetes.io/docs/concepts/storage/volumes/#emptydir)
- [hostpath](https://kubernetes.io/docs/concepts/storage/volumes/#hostpath)
- [projected](https://kubernetes.io/docs/concepts/storage/volumes/#projected)

```yaml
#config map mount example
---
apiVersion: v1
data:
  conf: abrakadabra
kind: ConfigMap
metadata:
  creationTimestamp: null
  name: tcm
---
apiVersion: v1
kind: Pod
metadata:
  name: cm-mount
  namespace: default
spec:
  containers:
  - name: cm-mount
    image: busybox
    command: ["sh", "-c", "sleep 120"]
    imagePullPolicy: IfNotPresent
    volumeMounts:
    - name: confmapvol
      mountPath: /data
  volumes:
  - name: confmapvol
    configMap:
      name: tcm
      items:
        - key: conf
          path: conf
```
Tady malá odbočka:
{{< figure src="dockercommandvsKubernetes.png" caption="docker-vs-kubernetes" >}}

## 2. Persistent Volumes
[https://kubernetes.io/docs/concepts/storage/persistent-volumes/](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)  
V rychlosti udělám souhrn.  
Zatímco **volumes** jsou definovány interně v rámci deploy a kubernetes se o jejich lifecycle nijak nestará. PersistenceVolume je vlastně samostatná vrstva API která izoluje definici a tvorbu storage od její konzumace deploymentem.  
*budeme o tom mluvit*  

vypíchneme zde malou definici PersistentVolume a PersistentVolumeClaim:  
>A PersistentVolume (PV) is a piece of storage in the cluster that has been provisioned by an administrator or dynamically provisioned using Storage Classes. It is a resource in the cluster just like a node is a cluster resource. PVs are volume plugins like Volumes, but have a lifecycle independent of any individual Pod that uses the PV. This API object captures the details of the implementation of the storage, be that NFS, iSCSI, or a cloud-provider-specific storage system.
  
>A PersistentVolumeClaim (PVC) is a request for storage by a user. It is similar to a Pod. Pods consume node resources and PVCs consume PV resources. Pods can request specific levels of resources (CPU and Memory). Claims can request specific size and access modes (e.g., they can be mounted ReadWriteOnce, ReadOnlyMany or ReadWriteMany, see AccessModes).

```sh
➤ kb api-resources|awk 'NR==1 || /PersistentVolume/'
NAME                              SHORTNAMES   APIVERSION                             NAMESPACED   KIND
persistentvolumeclaims            pvc          v1                                     true         PersistentVolumeClaim
persistentvolumes                 pv           v1                                     false        PersistentVolume
```

PersistenceVolume můžeme rozdělit na dvě části **STATICKÉ a DYNAMICKÉ**, začneme statickou.  

### 2.1 Static Persistence Volume

Vytvoříme statické PV typu **hostpath**, v ideálním světě by tohle dělal asi admin a řekl by BFU tady je a děj se vůle boží
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: static-pv01
spec:
  accessModes:
  - ReadWriteOnce 
  storageClassName: "" #nepouzijeme dynamiku
  capacity:
    storage: 10Mi
  hostPath:
    path: /tmp/static-pv01
    type: DirectoryOrCreate #pokud adresar neni tak vytvor
  nodeAffinity: #chceme aby se vytvoril na nodu k3d-deadless-agent-0
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - k3d-deadless-agent-0
  persistentVolumeReclaimPolicy: Delete #pokud nebude zadny PVC ktery by referencoval tak smaz
  claimRef: #povolime aby ho claimoval pouze PVC static-pvc z namespacu default
     namespace: default
     name: static-pvc01
```
> ReadWriteOnce -- the volume can be mounted as READ-WRITE by SINGLE NODE
> ReadOnlyMany -- the volume can be mounted READ-ONLY by MANY NODES
> ReadWriteMany -- the volume can be mounted as READ-WRITE by MANY NODES

{{< figure src="accessmodes.png" caption="accessModes overview" >}}
  
  
> A PVC to PV binding is a one-to-one mapping, using a ClaimRef which is a bi-directional binding between the PersistentVolume and the PersistentVolumeClaim.

```sh
➤ kb get pv static-pv01
NAME          CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM                  STORAGECLASS   REASON   AGE
static-pv01   10Mi       RWO            Delete           Available   default/static-pvc01                           2m27s
```

Ok uděláme PVC které pak dále budeme referencovat  v DEPOLYMENTU

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: static-pvc01
  namespace: default
spec:
  storageClassName: ""
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Mi
```
```sh
➤ kb get pvc static-pvc01 && kb get pv static-pv01
NAME           STATUS   VOLUME        CAPACITY   ACCESS MODES   STORAGECLASS   AGE
static-pvc01   Bound    static-pv01   10Mi       RWO                           72s
NAME          CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                  STORAGECLASS   REASON   AGE
static-pv01   10Mi       RWO            Delete           Bound    default/static-pvc01                           10m
```
Ok a deployment ktery bude referencovat vytvořené PVC
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: static-busy
  name: static-busy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: static-busy
  template:
    metadata:
      labels:
        app: static-busy
    spec:
      containers:
      - image: busybox
        command: ["sh", "-c", "sleep 120"]
        name: busybox-static01
        volumeMounts:
          - name: static
            mountPath: /data
      volumes:
      - name: static
        persistentVolumeClaim:
          claimName: static-pvc01
```
**Všimněte si že pod běží na stejném nódu na kterém je vytvořeno PV.**
```sh
➤ kb get pods static-busy-579b7645d7-4fhqn -o=json|jq .spec.nodeName
"k3d-deadless-agent-0"
```

```sh
#stav na nodu
➤ /usr/bin/docker ps |grep agent-0|awk '{print $1}'|xargs -I'{}'  /usr/bin/docker  exec -t {} ls -la /tmp
```

Ještě testneme škálování a affinitu vyškálovaných podů a pak deployment smažeme, následně smažeme PVC a uvidíme co se stane s PV.

**HostPath jde udělat přímo jako volume, pak samozřejmě žádné PV/PVC není potřeba a ani nevznikne**


### 2.2 Dynamic Persistence Volume
[https://kubernetes.io/docs/concepts/storage/persistent-volumes/#dynamic](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#dynamic)  
Zatímco u statického persistence provisioningu vytváříme PV sami, u dynamického přichází na hry STORAGECLASS což je vlastně takový automat na vytváření PV. Tzn pokud chceme použít dynamiku musí byt alespoň jedna **Storageclass** definována.
  
K3d v defaultní konfiguraci nabízí jednu [StorageClass](https://rancher.com/docs/k3s/latest/en/storage/)
  

```sh
➤ kb get sc
NAME                   PROVISIONER                            RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
local-path (default)   rancher.io/local-path                  Delete          WaitForFirstConsumer   false                  8h
```
SC ma nastaveno [VolumeBindingMode: WaitForFirstCustomer](https://kubernetes.io/docs/concepts/storage/storage-classes/#volume-binding-mode)  
Takže uděláme si podobný workload jako v minulém příkladě jen s použitím SC.

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dynamic-pvc01
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 10Mi
```
```sh
➤ kb get pvc
NAME            STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
dynamic-pvc01   Pending                                      local-path     64s
```
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: dynamic-ngx
  name: dynamic-ngx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dynamic-ngx
  template:
    metadata:
      labels:
        app: dynamic-ngx
    spec:
      containers:
      - name: dynamic-ngx
        image: nginx:stable-alpine
        imagePullPolicy: IfNotPresent
        volumeMounts:
        - name: dyn
          mountPath: /data
        ports:
        - containerPort: 80
      - image: bash
        command: ["bash", "-c", "x=0;while true;do ((x=x+1));sleep 1;echo $x > /data/ticktock;done"]
        name: dynamic-bash
        volumeMounts:
          - name: dyn
            mountPath: /data
      volumes:
      - name: dyn
        persistentVolumeClaim:
          claimName: dynamic-pvc01
```
```sh
➤  kb get pvc dynamic-pvc01 && kb get pv pvc-b9a9caff-ab3e-471d-94ca-41cb4644fecb
NAME            STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
dynamic-pvc01   Bound    pvc-b9a9caff-ab3e-471d-94ca-41cb4644fecb   10Mi       RWO            local-path     4m10s
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                   STORAGECLASS   REASON   AGE
pvc-b9a9caff-ab3e-471d-94ca-41cb4644fecb   10Mi       RWO            Delete           Bound    default/dynamic-pvc01   local-path              2m9s
```
A vzniklé PV
```yaml
➤ kb neat get pv pvc-b9a9caff-ab3e-471d-94ca-41cb4644fecb -o yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  annotations:
    pv.kubernetes.io/provisioned-by: rancher.io/local-path
  name: pvc-b9a9caff-ab3e-471d-94ca-41cb4644fecb
spec:
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: 10Mi
  claimRef:
    apiVersion: v1
    kind: PersistentVolumeClaim
    name: dynamic-pvc01
    namespace: default
    resourceVersion: "35571"
    uid: b9a9caff-ab3e-471d-94ca-41cb4644fecb
  hostPath:
    path: /var/lib/rancher/k3s/storage/pvc-b9a9caff-ab3e-471d-94ca-41cb4644fecb_default_dynamic-pvc01
    type: DirectoryOrCreate
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - k3d-deadless-server-0
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-path
```

**Tolik zatím k dynamice a statice, určitě si to vyzkoušejte. Má to navíc pár aspektů které si probereme příště.Skuste se nad tím zamyslet co to přináší**

## 3. Definice nové SC a ReadWriteMany
Jelikož se mi na k3d nepodařilo rozchodit blockdevice provisioner [LongHorn](https://github.com/longhorn/longhorn).  

> VOLUNTEER WANTED: pokud byste se toho chtel nekdo chytit a skusit to rozbehat tak cenim, celkem rád bych viděl ten LONGHORN funkční a někoho kdo se do něj více ponoří. Problém proč to nefunguje je na 99% K3D (iSCSI)

{{< figure src="neo.jpg" caption="I want you!!" >}}

**Udělal jsem řešení jednodušši a to použití NFS provisioneru. V podstatě se jedná o NFS server běžící na master nodu.**  
**NFS používá default SC pro vytvoření oddílu který obhospodařuje. Na simulaci ReadWriteMany a StatefulSetu je to dostatečné.**  

[origin git repo](k8s.gcr.io/sig-storage/nfs-provisioner)  
[helm git repo](https://github.com/kubernetes-sigs/nfs-ganesha-server-and-external-provisioner)  
> K Helmu a jiným templatovacím nástrojům se dostaneme později.
```sh
➤ git clone https://github.com/kubernetes-sigs/nfs-ganesha-server-and-external-provisioner

#template resource k nahlednuti pak v adresari render (neni nutne delat ale je fajn se do toho podivat)
➤ helm template nfs-server-provisioner .  \
  --namespace nfs-server-provisioner --create-namespace \
  --set persistence.storageClass="local-path" \
  --set persistence.size="5Gi" \
  --set persistence.enabled=true \
  --set "mountOptions={tcp,nfsvers=4.1}" \
  --output-dir render

#install
➤ helm install nfs-server-provisioner .  \
  --namespace nfs-server-provisioner --create-namespace \
  --set persistence.storageClass="local-path" \
  --set persistence.size="5Gi" \
  --set persistence.enabled=true \
  --set "mountOptions={tcp,nfsvers=4.1}"
```
```sh
➤ kb get sc
NAME                   PROVISIONER                            RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
local-path (default)   rancher.io/local-path                  Delete          WaitForFirstConsumer   false                  10h
nfs                    cluster.local/nfs-server-provisioner   Delete          Immediate              true                   12s
```
a jak vidíte vzal si 5GB disk 
```sh
➤ oc get pv|awk 'NR==1 ||/nfs/'
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                                                  STORAGECLASS   REASON   AGE
pvc-013000fa-bb3c-49f7-9293-04d36ba715f8   5Gi        RWO            Delete           Bound    nfs-server-provisioner/data-nfs-server-provisioner-0   local-path              84s
```

Takže ok máme SC a teď si skusíme dynamicky udělat nějaký PV jako ReadWriteMany. 

```yaml
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: nfs-pvc01
spec:
  storageClassName: "nfs"
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 100Mi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: nfs-bash
  name: nfs-bash
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nfs-bash
  template:
    metadata:
      labels:
        app: nfs-bash
    spec:
      containers:
      - image: bash
        command: ["sh", "-c", "sleep 120"]
        name: busybox-static01
        volumeMounts:
          - name: nfs
            mountPath: /data
      volumes:
      - name: nfs
        persistentVolumeClaim:
          claimName: nfs-pvc01
```
PV vytvořený SC
```yaml
➤ kb neat get pv pvc-e7c48e08-c610-454c-ae22-464e1cb6628e -o yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  annotations:
    EXPORT_block: "\nEXPORT\n{\n\tExport_Id = 1;\n\tPath = /export/pvc-e7c48e08-c610-454c-ae22-464e1cb6628e;\n\tPseudo
      = /export/pvc-e7c48e08-c610-454c-ae22-464e1cb6628e;\n\tAccess_Type = RW;\n\tSquash
      = no_root_squash;\n\tSecType = sys;\n\tFilesystem_id = 1.1;\n\tFSAL {\n\t\tName
      = VFS;\n\t}\n}\n"
    Export_Id: "1"
    Project_Id: "0"
    Project_block: ""
    Provisioner_Id: 0eee7408-12ab-45a9-a28e-c76eab64144d
    kubernetes.io/createdby: nfs-dynamic-provisioner
    pv.kubernetes.io/provisioned-by: cluster.local/nfs-server-provisioner
  name: pvc-e7c48e08-c610-454c-ae22-464e1cb6628e
spec:
  accessModes:
  - ReadWriteMany
  capacity:
    storage: 100Mi
  claimRef:
    apiVersion: v1
    kind: PersistentVolumeClaim
    name: nfs-pvc01
    namespace: default
    resourceVersion: "37860"
    uid: e7c48e08-c610-454c-ae22-464e1cb6628e
  mountOptions:
  - tcp
  - nfsvers=4.1
  nfs:
    path: /export/pvc-e7c48e08-c610-454c-ae22-464e1cb6628e
    server: 10.43.138.238
  persistentVolumeReclaimPolicy: Delete
  storageClassName: nfs
```
Vyškálujeme a jelikož nemáme žádnou affinitu a ReadWriteMany měli by se pody rozprostřít mezi vícero nódů
```sh
➤ kb scale deployment --replicas 3 nfs-bash

# a bingo
➤ kb get pods -l app=nfs-bash -o=jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.nodeName}{"\n"}'
nfs-bash-86f8d6494-mxlqv        k3d-deadless-agent-1
nfs-bash-86f8d6494-br2vm        k3d-deadless-agent-0
nfs-bash-86f8d6494-zj8wh        k3d-deadless-agent-0
```

{{< figure src="8ea21.jpg" >}}

## 4.StatefulSet
Do teď jsme řešili jen deployment a ten jak se zdá není pro state plně vhodný, existuje spousta případů kdy je jeho použití v pořádku ale také existuje spousta případů kdy není.  
Pro druhou možnost Kubernetes nabízí specialní objekt **StatefullSet (STS)**.
  

**Rozdíl mezi StatefullSetem a Deploymentem(Podem) ze Stackoverflow. Lépe bych to asi nedokázal formulovat tak tady to máte.**  

Yes, a regular pod can use a persistent volume. However, sometimes you have multiple pods that logically form a "group". Examples of this would be database replicas, ZooKeeper hosts, Kafka nodes, etc. In all of these cases there's a bunch of servers and they work together and talk to each other. What's special about them is that each individual in the group has an identity. For example, for a database cluster one is the master and two are followers and each of the followers communicates with the master letting it know what it has and has not synced. So the followers know that "db-x-0" is the master and the master knows that "db-x-2" is a follower and has all the data up to a certain point but still needs data beyond that.

**In such situations you need a few things you can't easily get from a regular pod:**  

- **A predictable name:** you want to start your pods telling them where to find each other so they can form a cluster, elect a leader, etc. but you need to know their names in advance to do that. Normal pod names are random so you can't know them in advance.
- **A stable address/DNS name:** you want whatever names were available in step (1) to stay the same. If a normal pod restarts (you redeploy, the host where it was running dies, etc.) on another host it'll get a new name and a new IP address.
- **A persistent link between an individual in the group and their persistent volume:** if the host where one of your database master was running dies it'll get moved to a new host but should connect to the same persistent volume as there's one and only 1 volume that contains the right data for that "individual". So, for example, if you redeploy your group of 3 database hosts you want the same individual (by DNS name and IP address) to get the same persistent volume so the master is still the master and still has the same data, replica1 gets it's data, etc.
  
[StatefulSets solve these issues because they provide all formers](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)  

    - Stable, unique network identifiers.
    - Stable, persistent storage.
    - Ordered, graceful deployment and scaling.
    - Ordered, graceful deletion and termination.  
I didn't really talk about (3) and (4) but that can also help with clusters as you can tell the first one to deploy to become the master and the next one find the first and treat it as master, etc.
  
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  namespace: default
  name: exsts
  labels:
    app: exsts
spec:
  selector:
    matchLabels:
      app: exsts # has to match .spec.template.metadata.labels
  serviceName: exsts-svc #A Headless Service, to controll network domain --> service se nevytvori dynamicky
  updateStrategy:
    type: RollingUpdate
  replicas: 1 # by default is 1
  template:
    metadata:
      labels:
        app: exsts # has to match .spec.selector.matchLabels
    spec:
      # terminationGracePeriodSeconds: 10
      containers:
      - name: exsts
        image: docker.io/library/busybox:latest
        resources:
          requests:
            cpu: 50m
            memory: 100Mi
          limits:
            cpu: 50m
            memory: 100Mi
        command: ["/bin/sh", "-c", "--"]
        args: ["while true; do sleep 30;done;"]
        volumeMounts:
        - name: sts-novct
          mountPath: /dadada
      volumes:
        - name: sts-novct
          persistentVolumeClaim:
            claimName: sts-pvc01
```
Ok ale pokud naškálujeme budeme muset mít persistent volume RW many, STS se s tímto vypořádává přez volumeclaimTemplate

```yaml
  volumeClaimTemplates:
  - metadata:
      name: exsts-vct
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: "local-path"
      resources:
        requests:
          storage: 1Gi
```

**Headless Service** aka spec.serviceName  
```yaml
apiVersion: v1
kind: Service
metadata:
  name: exsts-svc
  labels:
    app: exsts
spec:
  clusterIP: None #dulezite
  selector:
    app: exsts
```
```sh
#svc
Server:         10.43.0.10
Address:        10.43.0.10:53

Name:   exsts-svc.default.svc.cluster.local
Address: 10.42.2.14
Name:   exsts-svc.default.svc.cluster.local
Address: 10.42.0.42
Name:   exsts-svc.default.svc.cluster.local
Address: 10.42.2.16

#pod
nslookup exsts-0.exsts-svc.default.cluster.local
Server:         10.43.0.10
Address:        10.43.0.10:53
```
*As some have noted, you can indeed can some of the same benefits by using regular pods and services, but its much more work. For example, if you wanted 3 database instances you could manually create 3 deployments and 3 services. Note that you must manually create 3 deployments as you can't have a service point to a single pod in a deployment. Then, to scale up you'd manually create another deployment and another service. This does work and was somewhat common practice before PetSet/PersistentSet came along. Note that it is missing some of the benefits listed above (persistent volume mapping & fixed start order for example).*



Each connection to the service is forwarded to one randomly selected backing pod. But what if the client needs to connect to all of those pods? What if the backing pods themselves need to each connect to all the other backing pods. Connecting through the service clearly isn’t the way to do this. What is?  

For a client to connect to all pods, it needs to figure out the the IP of each individual pod. One option is to have the client call the Kubernetes API server and get the list of pods and their IP addresses through an API call, but because you should always strive to keep your apps Kubernetes-agnostic, using the API server isn’t ideal.  

Luckily, Kubernetes allows clients to discover pod IPs through DNS lookups. Usually, when you perform a DNS lookup for a service, the DNS server returns a single IP — the service’s cluster IP. But if you tell Kubernetes you don’t need a cluster IP for your service (you do this by setting the clusterIP field to None in the service specification ), the DNS server will return the pod IPs instead of the single service IP. Instead of returning a single DNS A record, the DNS server will return multiple A records for the service, each pointing to the IP of an individual pod backing the service at that moment. Clients can therefore do a simple DNS A record lookup and get the IPs of all the pods that are part of the service. The client can then use that information to connect to one, many, or all of them.  

Setting the clusterIP field in a service spec to None makes the service headless, as Kubernetes won’t assign it a cluster IP through which clients could connect to the pods backing it.  

## Addon
[raft protokol ETCD](http://thesecretlivesofdata.com/raft/#overview)

## DOMCV
{{< figure src="gojohnygo.jpg" caption="go_johny_go" >}}
1. vytvořte cluster s 3 worker nody  
2. vytvořte default storage class pro libovolný provider (hostpath,nfs ...)  
3. vytvořte redis cluster jako STS s 6 pody. Pody budou "rovnoměrně" rozdistribuovanými mezi "worker nody" (tzn každý nód bude mít 2 pody) [REDIS CLUSTER](https://rancher.com/blog/2019/deploying-redis-cluster/)  
   Každý pod bude mít svůj vlastní PV a použije nadefinovanou SC.  
4. prověřte readiness a liveness proby pro jednotlivé pody, pokud nejsou nadefinujte je  
5. zpřístupněte databázi z venku (tzn přihlásíte se na ní ze svého lokálního hostu přez CLI)   
6. zjistěte jaký pod je leader  
4. smažte jeden worker nod clusteru a prověřte co se stalo s jednotlivými replikami redisu  

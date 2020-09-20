---
title: GKE custom load and scalling
date: 2019-03-01
author: Tomas Dedic
description: "GKE testy, NFS persistence, generování loadu "
#thumbnail: "img/placeholder.jpg" # Optional, thumbnail
lead: "Začátky práce s GKE, vytvoření a test škálování"
disable_comments: true # Optional, disable Disqus comments if true
authorbox: false # Optional, enable authorbox for specific post
toc: false # Optional, enable Table of Contents for specific post
mathjax: false # Optional, enable MathJax for specific post
categories:
  - "Google Cloud Engine"
tags:
  - "GKE"
  - "docker"
menu: side # Optional, add page to a menu. Options: main, side, footer
sidebar: true
---
### Kubernetes GCE autoscaler
pouzijeme autoscale funkcionalitu clusteru a uvidime jak se to vlastne chova
!!!!zatim vynecham a vrhnema se na deployment a replicas
```bash
gcloud container clusters create autoscale-cluster \
--zone europe-west1-c \
--machine-type "g1-small" \
--disk-type "pd-standard" \
--disk-size "10" \
--node-locations "europe-west1-c" \
--num-nodes 2 --enable-autoscaling --min-nodes 1 --max-nodes 4 --enable-cloud-monitoring --addons HorizontalPodAutoscaling,HttpLoadBalancing
```
Trochu nechapu to ze autoscale se pouziva na nody ale ja bych ho spise potreboval na pody. Otestuju.
Puvodni myslenka ze prez netcat vyspavnim md5sum /dev/zero a budu tim zatezovat CPU uplne nevychazi jelikoz se mi nedari disownout proces ktery pousti netcat. Netcat tim ceka nez proces dobehne a muzu tak pustit max 1.
Skusim pouzit **at command** pro nashedulovani jobu prez netcat.
```bash
at now + 1 minute -f script.sh
```

### Deployments
A Deployment controller provides declarative updates for Pods and ReplicaSets.
vytvorime yaml:

[kubeloaddeployment.yaml](~/git_repositories/work/gce-kubernetes/kubeloaddeployment.yaml)
[kubeload-service.yaml](~/git_repositories/work/gce-kubernetes/kubeload-service.yaml)

```yaml
--- deployment spec kubeloaddeployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kubeload-deployment
  labels:
    app: load
spec:
  replicas: 3
  selector:
    matchLabels:
      app: load
  template:
    metadata:
      labels:
        app: load
    spec:
      containers:
        - name: kubeload
          image: veryraven/cmindeb:v2
          ports:
            - containerPort: 1500
```

```bash
kubectl create -f kubeloaddeployment.yaml
#prepiseme ho jako 
kubectl apply -f novydeploy.yaml
kubectl get pods --show-labels
kubectl get deployments
kubectl rollout status deployment.v1.apps/kubeload-deployment
#image update tady uplne nevim 
kubectl --record deployment.apps/kubeload-deployment set image deployment.v1.apps/kubeload-deployment kubeload=veryraven/cmindeb:v3
kubectl set image deployment.v1.apps/kubeload-deployment kubeload=veryraven/cmindeb:v3 --record=true
kubectl describe deployments
kubectl get deployment kubeload-deployment -o yaml

#kdyz udelam chybu pri zmene tak rollback 
kubectl rollout history deployment.v1.apps/kubeload-deployment
kubectl rollout history deployment.v1.apps/kubeload-deployment --revision=2
kubectl rollout undo deployment.v1.apps/kubeload-deployment
#Alternatively, you can rollback to a specific revision by specify that in --to-revision

#scaling
kubectl scale deployment.v1.apps/kubeload-deployment --replicas=10
#Assuming horizontal pod autoscaling is enabled in your cluster, you can setup an autoscaler for your Deployment and choose the minimum and maximum number of Pods you want to run based on the CPU utilization of your existing Pods.
# average utilization 80%CPU 
kubectl autoscale deployment.v1.apps/kubeload-deployment --min=10 --max=15 --cpu-percent=80
kubectl get hpa #HorizontalPodAutoscaling settings
```

### generovani loadu a test autoscaling

+ muzeme pouzit autoscale horizontal nodes, autoscale horizontal pods, autoscale vertical pods
+ pouzijeme slabsi stroje pro cluster

```bash
  gcloud compute machine-types list
  gcloud container clusters create autoscale-cluster \
  --zone europe-west1-c \
  --machine-type "g1-small" \
  --disk-type "pd-standard" \
  --disk-size "10" \
  --node-locations "europe-west1-c" \
  --num-nodes 1 --enable-autoscaling --min-nodes 1 --max-nodes 4 --enable-cloud-monitoring --addons HorizontalPodAutoscaling,HttpLoadBalancing

kubectl create -f kubeloaddeployment.yaml
kubectl create -f kubeload-service.yaml
kubectl autoscale deployment.v1.apps/kubeload-deployment --min=1 --max=15 --cpu-percent=20
kubectl get services #najdeme public endpoint
telnet ENDPOINT 1500
kubectl get hpa # vidime jak se rozjizdi load
```

### AUTOSCALING on multiple metrics
```bash
kubectl top pods
kubectl top nodes
```
**tady je zajimave ruzne API pro volani, zcela nerozumim rozdilu mezi jednotlivymi API verzemi**
```bash
--nefunguje:
kubectl get deployment.v2beta1.apps -o yaml

--ale funguje
kubectl get hpa.v2beta1.autoscaling -o yaml
--zaroven funguje
kubectl get hpa.v1.autoscaling -o yaml
```
---> custom metriky jsou dost slozite a asi to bude chtit prozkoumat API server co umoznuje, idealne konečně pochopit SWAGGER abych si vyjel vše co umožňuje API

### PERSISTENT DISK between kubernetes pods
--------------------
Myšlenka je taková mít jeden disk pro logování který se automaticky připojí k novému **podu** po jeho zařazení.

*Kubernetes has volumes. Volumes let your pod write to a filesystem that exists as long as the pod exists.*

Type of storage			How long does it last?  
Container filesystem	Container lifetime   
Volume					Pod lifetime  
Persistent volume		Cluster lifetime  

Postavíme samostatný NFS server který bude prezentovat data.
```bash
gcloud compute disks create --size=1GB --zone="europe-west1-c" kp-nfs-disk
```
Vytvoříme NFS server
[nfs-server.yaml](~/git_repositories/work/gce-kubernetes/nfs-server.yaml)
Vytvoříme příslušné service
[nfs-service.yaml](~/git_repositories/work/gce-kubernetes/nfs-service.yaml)
Create Persistent Volume and Persistent Volume Claims
[persistent-volume-claim.yaml](~/git_repositories/work/gce-kubernetes/persistent-volume-claim.yaml)
Použije se pak pro pody aby věděli co claimovat
Jediný trik je v adresaci nfs server mělo by to být něco jako **service-name.namespace.svc.cluster.local** v našem případě nfs-service.default.svc.cluster.local a nebo IP adresa
```yaml
  nfs:
    server: 10.19.249.83
    path: "/"
```
Poslední krok je upravit POD aby reflektovat a automountoval
[kubeload-deployment-nfs.yaml](~/git_repositories/work/gce-kubernetes/kubeload-deployment-nfs.yaml)

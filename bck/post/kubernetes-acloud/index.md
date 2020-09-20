---
title: Kubernetes acloud notes/screenshots
date: 2019-05-23
author: Tomas Dedic
description: "kubernetes basics"
disable_comments: true # Optional, disable Disqus comments if true
authorbox: false # Optional, enable authorbox for specific post
toc: true # Optional, enable Table of Contents for specific post
# thumbnail: "img/2b177514c3375a25544f763db89c4c3c.jpg"
mathjax: false # Optional, enable MathJax for specific post
sidebar: true
draft: false
context: "poznamky a galerie k kubernetes z acloudu"
# images: "images"
categories:
  - "BUJAKA"
tags:
  - "Kubernetes"
  - "BUJAKA"
resources:
- src: "screenshots/*.png"
  name: gallery-:counter
  title: gallery-title-:counter
---
Kubernetes poznamky z kurzu acloud guru. Nema to moc strukturu a asi by to chtelo vice dopracovat.


### COMMON
```bash
kubectl run curl --image=radial/busyboxplus:curl -i --tty
kubectl attach curl-87b54756-gl82f -c curl -i -t

kubectl get nodes -o jsonpath='{.items[*].spec.podCIDR}'
kubectl apply -f file.yaml 
kubectl get deployment test --watch
kubectl rollout status deploy test
kubectl get rs -o wide
kubectl apply -f file.yaml  --record
kubectl rollout history deploy test #command se nam zobrazi protoze jsme dali record
kubectl rollout history deploy test --revision=3
kubectl rollout undo deploy test #to previous version
```

**!!!pouzivat pods with resource request!!!**  
kubernetes insecure port
kubernetes not do users!!! ---> all users has to be created outside to cluster  
integrate AKS (Azure kubernetes service) cluster with Azure Active directory using OpenID client  
autentification=AUTHN  
autorization=AUTHZ  

### RBAC
**Role and RoleBinding**  
**Role vs Clusterrole** --->clusterrole neni vazana na namespace
```bash
kubectl get clusterrolebindings
kubectl get clusterrolebindings rolename -o yaml
kubectl get clusterrole cluster-admin -o yaml
kubectl get clusterrole
```


Admission control ---> custom politika pro objekty (od kud stahuju images, jaky typ ...)

### ADD USER TO CLOUD
```bash
openssl genrsa -out ts.key 2048
openssl req -new -key ts.key -out ts.csr -subj "/CN=ts/O=acg"
CN ---> musi byt jmeno uzivatele
O  ---> user group
podepiseme certifikat prez CA
openssl x509 -req in ts.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out ts.crt -days 365
~/.kube/config
kubect config set-credentials ts --client-certificate=ts.crt --client-key=ts.key
kubectl config set-context ts --cluster=cluster.name --namespace=acg --user=ts
kubectl config use-context ts
```
novy uzivatel ma ale vsechno zakazane potrebujeme roli a binding
```bash
---
kind: ClusterRole #can access all namespaces
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: acgrbac
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]

kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: acgrbac
  namespace: acg
subjects:
- kind: User
  name: mia
  apiGroup: ""
roleRef:
  kind: ClusterRole
  name: acgrbac
  apiGroup: ""
---
```
### KUBERNETES more:
DaemonSet(ds) -konkretni pod bezi na kazdem nodu takze pri pridavani/odstreneni nodu to resi
StatefulSet(sts) 
job - run specified number of pods and they complete properly
cronjob - pods nastartuji kdy chceme
PodSecurityPolicy(psp) -co musi pod splnovat aby mohl bezet na clusteru, muze byt jako Admission controler
Pod resource requests and limits --> vzdy pouzivat pro nove pody
(cpu limits kolik virtual jader dostane k dispozici, requests aby se pod vlezl na nod kam ho chce dat --> vetsinou se limits a requests nastavuje stejne)
ResourceQuota - rozdelit na namespaces a aplikovat resourcove omezeni
CustomResourceDefinition(crd) -


iputils-ping curl dnsutils iproute2 

kubectl exec -it pod_name copustit
kubectl create secret generic mysql-pass --from-literal=password=Password123


{{% gallery folder="" title="[Kubernetes gallery]" %}}


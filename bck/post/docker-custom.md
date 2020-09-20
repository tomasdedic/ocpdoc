---
title: Docker custom image
date: 2019-03-01
type: post
author: Tomas Dedic
description: "How to create docker custom image"
#thumbnail: "img/placeholder.jpg" # Optional, thumbnail
lead: "Docker customisation and errors in GKE"
disable_comments: true # Optional, disable Disqus comments if true
authorbox: false # Optional, enable authorbox for specific post
toc: false # Optional, enable Table of Contents for specific post
mathjax: false # Optional, enable MathJax for specific post
categories:
  - "Google Cloud Engine"
  - "Prometheus"
tags:
  - "docker"
  - "GKE"
menu: side # Optional, add page to a menu. Options: main, side, footer
sidebar: true
---
### Docker custom image
stahneme si image na kterem budeme stavet:
```
docker pull bitnami/minideb:latest #v tompto pripade minidebian
docker run --name cmindev -ti bitnami/minideb:latest
```
customizujeme a commit:
```
docker commit -m "python2.7,procps" id veryraven/cmindeb:v1 #dulezity je ten tag
```
push k sobe do repository
```
docker push veryraven/cmindeb:v1
```
Docker image ma entrypoint /bin/bash tzn ze exitne moznost jak to obejit je spoustet ho jako
**A docker container will run as long as the CMD from your Dockerfile takes.**
```
docker run --name -dit veryraven/cmindeb:v1
docker exec -it cmin /bin/bash
docker inspect veryraven/cmindeb:v1 #tady se ukaze co vsechno container spousti
```
Pripravime dockerfile a udelame build 
```
docker build -t veryraven/cmindeb:v2 .
```
Build si pushneme k sobe:
```
docker push veryraven/cmindeb:v2
#tohle se jiz nepouziva
#kubectl run kubeload --image veryraven/cmindeb:v2 --port=1500
kubectl run --generator=run-pod/v1 kubeload --image veryraven/cmindeb:v2 --port 1500 
kubectl expose pod kubeload --type="LoadBalancer"
```
pro prihlaseni na konretni pod:
```
kubectl exec -it  kubeload-587645c7f-f8lcw -c kubeload /bin/bash
```
nebo prez GCLOUD instance:
List instances:
```
gcloud compute instances list
```
SSH into instance:
```
gcloud compute ssh <instance_name> --zone=<instance_zone>
```
In the instance, list the running processes and their container IDs:
```
sudo docker ps -a
```
Attach to a container:
```
sudo docker exec -it <container_id> /bin/bash
```

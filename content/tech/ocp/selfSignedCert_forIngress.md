---
title: "Self signed cert for Ingress Nginx"
date: 2020-06-02 
author: Tomas Dedic
description: "Desc"
lead: "working"
categories:
  - "Azure"
tags:
  - "ACR"
---
Generate **self signed TLS certificate** for **Ingress** for use with **Artifactory docker registry**.
```sh
openssl req -newkey rsa:4096 -nodes -sha256 -keyout domain.key -x509 -days 365 -out domain.crt
kubectl create secret tls art-tls --cert=domain.crt  --key=domain.key
 # and customize ingress
ingress:
  tls:
    - secretName: art-tls
      hosts: ["artifactory.csas.elostech.cz"]
  annotations:
    kubernetes.io/ingress.class: "nginx"
```
Add certificate to local trust:  		
```sh
 #RHEL
sudo cp domain.crt /etc/pki/ca-trust/source/anchors/
 #DEBIAN
sudo cp domain.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
 #insecure registry just for information, will not use
 #will not work for bootstrap
cat /etc/docker/daemon.json
	{
	  "insecure-registries" : ["artifactory.apps.poshi4.csas.elostech.cz"]
		}
sudo systemctl restart docker.service
```

```sh
 # test
docker login -u user -p "qxYhJg2s41rJFAuHJNi2" artifactory.apps.poshi4.csas.elostech.cz

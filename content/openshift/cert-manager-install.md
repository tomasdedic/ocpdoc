---
title: "Instalace a zprovozňení cert-manager"
date: 2020-10-08 
author: Tomas Dedic
description: "SANDBOX"
lead: "Instalace a zprovozňení cert-manager pro automatickou obnovu certifikatu pro ingress"
categories:
  - "Openshift"
tags:
  - "SSL/TLS"
---
```sh
oc create namespace cert-manager
oc apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.0.1/cert-manager.yaml
#install cert manager operator
```

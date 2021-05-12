---
title: "Zátěžové testy"
date: 2021-04-14 
author: Tomas Dedic
description: "Desc"
lead: "working"
categories:
  - "Openshift"
tags:
  - "Chaos"
---
# TESTING TOOLS
Benchmark Operator for workload orchestration in k8s/ocp: https://github.com/cloud-bulldozer/benchmark-operator  
Kube-burner for control plane stress: https://github.com/cloud-bulldozer/kube-burner  
Kraken for chaos testing: https://github.com/cloud-bulldozer/kraken  

## Co chceme dosáhnout
Rád bych otestoval zvýšený load a v průběhu toho simuloval výpadky nódu/etcd/systémových podů.

## 1. KUBE-BURNER
```sh
#prometheus bearer token
SERVICE_ACCOUNT=sadmin #cluster admin
token=$(oc sa get-token sadmin)



## 2. KRAKEN

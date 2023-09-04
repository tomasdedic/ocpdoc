---
title: Loki multitenant on Infrastructure Openshift cluster
date: 2023-02-17
author: Tomas Dedic
description: "Loki multitenant loging, scalable, different backend for each cluster"
lead: "loki logging"
categories:
  - "Logging"
tags:
  - "loki"
thumbnail: "img/loki.png"
autonumbering: false
---
## DOC
[consistent hash ring - explanation, zajimal me tech pozadi](https://www.toptal.com/big-data/consistent-hashing) 

## Proč centrální LOKI
**Na centrální LOKI cluster se v tento okamžik díváme jako na úložiště logů pro OPS. Nemáme ambice nahrazovat budoucí řešení Monolog.**  
Hlavní výrazná změna Loki oproti ELK je ta že LOKI neindexuje všechny řádky logů, ale pouze metadata logu. Díky tomu je výrazně rychlejší ale zároveň na heuristické analýzy spíše méně vhodný.  

Logy na jednotlivých clusterech budou uloženy v lokálním ES s relativně krátkou retencí.
Všechny logy budou zároveň z jednotlivých OCP clusterů přez CLusterLogForwarder směrovány do OCP Infra clusteru.  
**Pro každý cluster vznikne instance LOKI s backendem postaveným nad S3 storage.**  
Nebudeme tedy provozovat multitenanci na úrovni LOKI.

Pro instalaci použijeme simpleScalable schéma s oddělením Read a Write streamu.
{{< figure src="img/image5.png " caption="caption" >}}
{{< figure src="img/image6.png " caption="caption" >}}



## Multitenant 
What about the following approach:

Use one S3 bucket for storage
Use one tenant_id per cluster, f.x dev-cluster & staging-cluster
Loki instance on each cluster only querying data for it's given tenant_id with multi_tenant_queries_enabled: false
Observer cluster running only loki (not promtail) with all tenant_id's piped in the X-Scope-OrgID header such as
dev-cluster | staging-cluster and multi_tenant_queries_enabled: true
Is this something that could work?

## Instalace
Chceme dosáhnout loki clusteru tak aby data z jednotlivých clusterů byly v samostatných Bucketech( 1 bucket per cluster)
Multitenant zatím řešit nebudeme. Data budou dostupná všem.
Zatím není zřejmé zda použijeme simpleScalable nebo microservice mode.
```bash
Bucket endpoint (port 443/https)
10.177.28.240 iocp4s-loki.pphcpcs01.vs.csin.cz
10.177.28.240 tocp4s-loki.pphcpcs01.vs.csin.cz
10.177.28.240 zocp4s-loki.pphcpcs01.vs.csin.cz
10.177.28.240 pocp4s-loki.pphcpcs01.vs.csin.cz

Access key:
Wl9oeVFT_iQNDJOMVH4Fr8ATp_HkODH0QJ2avs74XFDUlVxMAn2v7NtpPRsHAgECupUBEMCcwsoz8Lo

Secret key:
ffba5256-2f42-4095-b67b-27b7268a9dd7
```


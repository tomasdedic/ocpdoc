---
title: "FluentD"
date: 2020-06-19 
author: Tomas Dedic
description: "fluentD struggle"
lead: "all your base are belong to us"
categories:
  - "Openshift"
tags:
  - "OCP"
  - "LOGGING"

---
Konfigurace fluentD v rámci Openshift clusteru. 
Bude řešen sběr a směrování logů typu SystemD, ContainerLog, EventLog (Etcd API store). Obohacování jednotlivých zpráv a směrování do ElasticSearch a Kafka (prezentovaná EventHubem). Krizové stavy, lokální ukládání (buffering) a následné zpracování po obnovení konektivity na koncové služby.




---
title: "FluentD configuration"
date: 2021-06-01
author: Tomas Dedic
description: "fluentD struggle"
lead: "all your base are belong to us"
categories:
  - "Openshift"
  - "LOGGING"
tags:
  - "FluentD"
  - "LOGGING"
thumbnail: "img/fluent.jpg"
toc: true
numbering: true 
---
Konfigurace fluentD v rámci Openshift clusteru. 
Bude řešen sběr a směrování logů typu SystemD, ContainerLog, EventLog (Etcd API store). Obohacování jednotlivých zpráv a směrování do ElasticSearch a Kafka (prezentovaná EventHubem). Krizové stavy, lokální ukládání (buffering) a následné zpracování po obnovení konektivity na koncové služby.




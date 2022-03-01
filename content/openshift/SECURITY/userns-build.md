---
title: "Build in linux namespace"
date: 2022-03-01 
author: Tomas Dedic
description: "Desc"
lead: "working"
categories:
  - "Openshift"
tags:
  - "deploy"
  - "security"
---

# Použití pro userNS v GITHUB actions runners

## SCC pro runner
+ pokud chceme aby mohl fungovat **podman run** tzn v případě multistage buildu
  je potřeba pro SA nakonfigurovat **scc privileged**
+ pokud nepotřebujeme **podman run** stačí **scc anyuid**

## UID mapping
V cri-o runneru na OCP je pouze jeden workloadclass podporující userNS a to
**io.openshift.builder** a proto je potřeba ho anotovat.
```yaml
#anotace podu pro využití userns
  annotations:
    openshift.io/scc: anyuid
    io.kubernetes.cri-o.userns-mode: "auto:size=65536;map-to-root=true"
    #hodnota 65536 asi není potřeba tak vysoká bude stačit o řád nižší
    io.openshift.builder: "true"
``` 
Předchozí anotace provede mapping mezi UID unvitř kontajneru (v našem případě
workload běží pod uživatelem 1001(runner))

```sh
#inspekce na worker nodu
#pro testy runner běží ve sleepu

#check userns
sh-4.4# lsns -t user
        NS TYPE  NPROCS    PID USER   COMMAND
4026531837 user     217      1 root   /usr/lib/systemd/systemd --switched-root --system --deserialize 17
4026532928 user      10 156171 166537 sh -c sleep 1000000
#proces je puštěn pod užiatelem 166537

#uid mapping
sh-4.4# cat /proc/156171/uid_map
         0     165536      65536
# mapping je lineární tedy UID 0 unvitř kontejneru má UID 165536 z pohledu
# openshift node         

# náš proces běžící pod UID 1001 runner unvitř kontejneru bude tedy mít
# 165536+1001 = 166537

# a je namapován na efektivní práva uživatele containers
sh-4.4# cat /etc/subuid
core:100000:65536
containers:165536:65536
containers:200000:16000000

```


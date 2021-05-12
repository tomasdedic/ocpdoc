---
title: "Change VM type for master and worker node"
date: 2021-03-09 
author: Tomas Dedic
description: "Howto"
lead: ""
categories:
  - "Openshift"
tags:
  - "CONFIG"
thumbnail: "img/changevmtitle.jpg"
---
**Chceme změnit VM type na D8as_v4/D4as_v4.**
```sh
# vysledny stav
[oaz-deva@ipocpbas01 machines]$ oc get machines
NAME  PHASE     TYPE               REGION       ZONE   
oaz   Running   Standard_D8as_v4   westeurope   2      
oaz   Running   Standard_D8as_v4   westeurope   1      
oaz   Running   Standard_D8as_v4   westeurope   3      
oaz   Running   Standard_D4as_v4   westeurope   1      
oaz   Running   Standard_D4as_v4   westeurope   2      
oaz   Running   Standard_D4as_v4   westeurope   3      
```

## WORKER NODY
```sh
# Zazalohovat si vsechny machinesets
oc get machinesets -n openshift-machine-api -o yaml|neat  > machine-set.yaml
# upravit a apply, slo by i prez oc edit
# smazat prislusny machineset
oc delete machinesets -n openshift-machine-api ${machine-set}
#Tim se ti odstrani vsechny VM z dane zony. a potom jak tam ty VM nemas, tak jej zase nahrej zpet.
oc apply -f machine-set.yaml
```
## MASTER NODY

Pokud vymenujeme nod, ktery je porouchany. Je vhodne dane VM v Azure vypnout, jinak nam to bude operator neustale nahazovat
1. Smazeme dany master v azure Tim se nam dostane ETCD do stavu, kdy bezi pouze na dva membery. bacha na balancer. ten z nejakeho duvodu silene timeoutuje a je to asi z duvodu pravidla.
   Neresme za cca 5 minut bude fungovat zase normalne
   Dobry hint je pripravit si servisni ucet kterym se prihlasim do OCP jelikoz OAuth bude nejspis nefunkcni

2. Pripojime se na jeden z bezicich ETCD memberu a vypiseme si jejich status
```sh
oc exec -n openshift-etcd -it master-0 -c etcdctl -- /bin/bash
etcdctl member list -w table
```
3. Odstranime nodu clusteru
```sh
etcdctl member remove <ID>
```
3. Odstranime secrety smazaneho nodu s OpenShiftu, jsou celkem 3 a po odstraneni se nam zase vytvori
```
oc get secrets -n openshift-etcd | grep master-0 
oc delete secrets -n openshift-etcd secrets
```
4. Vyeportujeme si machine z openshiftu a upravime jej
tady pozor na jednu svinarnu
V urovni spec zustava

**spec.providerID**

tento radek je nutne taky smazat, jinak to nebude fungovat
```sh
oc get machines -n openshift-machine-api master-0 -o yaml |neat >master0.yaml
oc delete machines -n openshift-machine-api master-0
oc applu -f master0.yaml
```
6. Zkontrolujeme stav etcd
```sh
etcdctl endpoint health
```
Pokud je vse OK, vsechny etcd membery budou ve stavu started a vsechny machine ve stavu running. Potom se muzes pustit do dalsiho masteru.
Me to trvalo asi 2 hodinky, nez jsem je vsechny vymenil 

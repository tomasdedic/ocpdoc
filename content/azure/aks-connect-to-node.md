---
title: "AKS pripojeni prez SSH k nodu v VMSS(scale set)"
date:  2021-02-21
author: Tomas Dedic
description: "Desc"
lead: "working"
categories:
  - "AZURE"
tags:
  - "AKS"
---
Jak nastavit ssh public key v AZURE pro VMSS a pod pro pripojeni z privatniho rozsahu.
```sh

az vmss extension set \
  --resource-group MC_opsdemo_opsdemoAKS_westeurope  \
  --vmss-name aks-nodepool1-63140802-vmss \
  --name VMAccessForLinux \
  --publisher Microsoft.OSTCExtensions \
  --version 1.4 \
  --protected-settings "{\"username\":\"core\", \"ssh_key\":\"$(cat ~/.ssh/id_rsa.pub)\"}"


az vmss update-instances \
  --instance-ids '*' \
  --resource-group MC_opsdemo_opsdemoAKS_westeurope \
# get private adress
az vmss nic list -g MC_opsdemo_opsdemoAKS_westeurope --vmss-name aks-nodepool1-63140802-vmss --query "[].ipConfigurations[].privateIpAddress" -o tsv
```
```sh
# get node internalIP adress
kb get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}' 
```
```sh
kb run -it --rm ssh-pod --image=debian
apt update && apt install openssh-client -y
kb cp ~/.ssh/id_rsa $(kubectl get pod -l run=ssh-pod -o jsonpath='{.items[0].metadata.name}'):/id_rsa
ssh -i id_rsa  core@IP
```

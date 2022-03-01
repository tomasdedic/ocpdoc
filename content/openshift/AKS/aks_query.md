---
title: "AKS query"
date: 2022-01-31
author: Tomas Dedic
description: "Desc"
lead: "working"
categories:
  - "AKS"
tags:
  - "AKS"
toc: false
autonumbering: false
---
```sh
rg=opsdemo
aksname=opsdemoAKS
#resourceRG
noderg=$(az aks show -g $rg -n $aksname --query nodeResourceGroup -o tsv)
lb=$(az network lb list -g $noderg -o tsv --query "[0]".name)
az network lb rule list -g $noderg --lb-name $lb -o table
az network lb probe list -g $noderg --lb-name $lb -o table
az network lb address-pool list -g $noderg --lb-name $lb -o table
az network lb address-pool list -g $noderg --lb-name $lb --query "[]".backendIpConfigurations"[]".id -o tsv
#routing
az network route-table list -g $noderg -o table
rtname=$(az network route-table list -g $noderg --query "[0]".name -o tsv)
az network route-table route list -g $noderg --route-table-name $rtname -o table
```

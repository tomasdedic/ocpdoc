---
title: "ARO install"
date: 2020-09-17 
author: Tomas Dedic
description: "Intalace ARO (AzureRedhatOpenshift)"
lead: ""
categories:
  - "Openshift"
  - "Azure"
tags:
  - "Install"
  - "ARO"
---
## Proces instalace
```
az provider register -n Microsoft.RedHatOpenShift --wait
az account set --subscription 7504de90-f639-4328-a5b6-fde85e0a7fd9
az account show
# je potreba pouzit az login na SP 
az login --service-principal --username 126501b0-ae03-4aad-aff2-19ced106b169 --password 05b154b3-afc3-42dd-bd53-746e6fa0d368 --tenant d2480fab-7029-4378-9e54-3b7a474eb327

export RESOURCEGROUP="aro-test"
export LOCATION="westeurope"
export CLUSTER="arozinite"
az group create --name $RESOURCEGROUP --location $LOCATION

az network vnet create \
--resource-group $RESOURCEGROUP \
--name aro-vnet \
--address-prefixes 10.10.8.0/22

az network vnet subnet create \
--resource-group $RESOURCEGROUP \
--vnet-name aro-vnet \
--name master-subnet \
--address-prefixes 10.10.8.0/23 \
--service-endpoints Microsoft.ContainerRegistry

az network vnet subnet create \
--resource-group $RESOURCEGROUP \
--vnet-name aro-vnet \
--name worker-subnet \
--address-prefixes 10.10.10.0/23 \
--service-endpoints Microsoft.ContainerRegistry

az network vnet subnet update \
--name master-subnet \
--resource-group $RESOURCEGROUP \
--vnet-name aro-vnet \
--disable-private-link-service-network-policies true

az aro create \
  --resource-group $RESOURCEGROUP \
  --name $CLUSTER \
  --vnet aro-vnet \
  --master-subnet master-subnet \
  --worker-subnet worker-subnet \
  --pull-secret @pull-secret.txt 
#  --apiserver-visibility Private \
#  --ingress-visibility Private 
#  --client-id "126501b0-ae03-4aad-aff2-19ced106b169" \
#  --client-secret "05b154b3-afc3-42dd-bd53-746e6fa0d368"
```
to delete
```sh
az aro delete --resource-group $RESOURCEGROUP --name $CLUSTER
```

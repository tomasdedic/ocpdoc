---
title: "Service principals ve vazbě na OCP"
date: 2020-10-11
author: Tomas Dedic
description: "uff"
lead: "Jaké Service Principals a oprávnění Openshift vytváří"
categories:
  - "Azure"
tags:
  - "Config"
  - "Security"
autonumbering: true

---

## Instalační SP
```yaml
az ad sp create-for-rbac --name service_principal_name
 #add roles
az role assignment create --assignee "app id of service principal" --role Contributor --output none
az role assignment create --assignee "app id of service principal" --role "User Access Administrator" --output none
#The User Access Administrator role enables the user to grant other users access to Azure resources
 # service principal needs read write owned by app permisions Azure AD graph
az ad app permission add --id "app id of service principal" \
-- api 00000002-0000-0000-c000-000000000000 \
-- api-permissions 824c81eb0e3f8-4ee6-8f6d-de7f50d565b7-Role
```

vytvořené SP tak bude mít Roli:  
**Application.ReadWrite.OwnedBy** --	Manage apps that this app creates or owns	Allows the calling app to create other applications and service principals, and fully manage those applications and service principals (read, update, update application secrets and delete), without a signed-in user. It cannot update any applications that it is not an owner of. Does not allow management of consent grants or application assignments to users or groups.
```sh
+ User Access Administrator
  subscription
+ Contributor
  subscription
```
## Vytvořená SP
Přez instalační SP jsou v průběhu instalace vytvořena další 3 SP

```sh
{cluster_resource_group}-openshift-image-registry-azure-{rand_suffix}
  + Contributor
    resourceGroups/{baseDomainResourceGroupName - shared}
    resourceGroups/{cluster resource group }
    resourceGroups/{vnet resource group }

{cluster_resource_group}-openshift-ingress-azure-{rand_suffix}
  + Contributor
    resourceGroups/{baseDomainResourceGroupName - shared}
    resourceGroups/{cluster resource group }
    resourceGroups/{vnet resource group }

{cluster_resource_group}-openshift-machine-api-azure-{rand_suffix}
  + Contributor
    resourceGroups/{baseDomainResourceGroupName - shared}
    resourceGroups/{cluster resource group }
    resourceGroups/{vnet resource group }
```

Zajímavé je že všechny vytvořená SP mají stejné přiřazené role.  
**Teoreticky by na OCP šla nahradit pouze jedním**

## Uložení SP a CLIENT secret z pohledu OCP
```sh
#SP {cluster_resource_group}-openshift-ingress-azure-{rand_suffix}
 for i in $(oc get secret -n openshift-machine-api azure-cloud-credentials -o json|jq -r '.data |keys []')
 do
      printf '%s\t' $i:;oc get secret -n openshift-machine-api azure-cloud-credentials -o json|jq -r ".data.$i"|base64 -d;printf '\n'
 done 

 # hlavní instalační SP
 for i in $(oc get secret -n kube-system azure-credentials -o json|jq -r '.data |keys []')
 do
      printf '%s\t' $i:;oc get secret -n kube-system azure-credentials -o json|jq -r ".data.$i"|base64 -d;printf '\n'
 done 

#{cluster_resource_group}-openshift-image-registry-azure-{rand_suffix}
 for i in $(oc get secret -n openshift-image-registry installer-cloud-credentials  -o json|jq -r '.data |keys []')
 do
      printf '%s\t' $i:;oc get secret -n openshift-image-registry installer-cloud-credentials -o json|jq -r ".data.$i"|base64 -d;printf '\n'
 done 


# {cluster_resource_group}-openshift-ingress-azure-{rand_suffix}
nepodařilo se mi najít
```
Je potřeba brát v úvahu že přez hlavní SP si OCP může vytořit další SP a na ně navázat potřebné aktivity.

## Vyjadření RedHat k SP
Below are the inline descriptions:  
 
-  <cluster_name>-identity
 
Is a managed identity created by the installer for attaching to all the VMs so that the kubelet and kube-controller-manager can communicate with azure APIs  
 
- <cluster_name>-openshift-image-registry-azure-cgwrf
 
- <cluster_name>-openshift-ingress-azure-hwdjj
 
- <cluster_name>-openshift-machine-api-azure-vrvdd
 
These are service principals (app registrations) for each operator in the cluster that needs to communicate with Azure APIs. These are created for the operators by virtue of CredentialRequests objects, realized by openshift-credential-operator.

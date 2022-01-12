---
title: "Customizing ArgoCD for SOPS usage"
date: 2021-02-15 
author: Tomas Dedic
description: "Nosná myšlenka automatický decrypting secretů přez Mozilla SOPS v workflow GITOPS tedy s využitím ArgoCD.  
              Pro storage klíčů použít Azure KV a přístup k němu řídit přez Managed Identitu zacílenou na deployment ArgoCD
              tedy použitím AAD pod identity."
lead: "Nasazeni SOPS pro GITOPS pouziti a auto decrypting prez Azure KV. Využití ManagedIdentity a AAD pod identity pro přístup k KV"
categories:
  - "Openshift"
tags:
  - "ARGOCD"
toc: true
autonumbering: true
thumbnail: "img/121367915_10157770255117399_360219505287172470_o.jpg"
---

# ArgoCD - pouziti SOPS pro auto decrypting prez managed Identitu

## AAD pod identity
Nakonfigurujeme **aad pod identity** tak aby propisoval UserManagedIdentitu nedefinovanou v Azure.
```sh
# AKS v azure pouziva kubenet
helm repo add aad-pod-identity https://raw.githubusercontent.com/Azure/aad-pod-identity/master/charts
helm install aad-pod-identity aad-pod-identity/aad-pod-identity --set nmi.allowNetworkPluginKubenet=true
# jedna replika nam staci
kb scale --replicas=1  deploy/aad-pod-identity-mic
```
```sh
# identity in azure v RG AKS
export IDENTITY_RESOURCE_GROUP='MC_opsdemo_opsdemoAKS_westeurope'
export IDENTITY_NAME='pod-identity'
az identity create -g ${IDENTITY_RESOURCE_GROUP} -n ${IDENTITY_NAME}
export SUBSCRIPTION_ID=$(az account show --query id -o tsv) 
export IDENTITY_RESOURCE_ID="$(az identity show -g ${IDENTITY_RESOURCE_GROUP} -n ${IDENTITY_NAME} --query id -otsv)" && echo ${IDENTITY_RESOURCE_ID}
export IDENTITY_CLIENT_ID="$(az identity show -g ${IDENTITY_RESOURCE_GROUP} -n ${IDENTITY_NAME} --query clientId -otsv)" && echo ${IDENTITY_CLIENT_ID}
export IDENTITY_ASSIGNMENT_ID="$(az role assignment create --role Reader --assignee ${IDENTITY_CLIENT_ID} --scope /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${IDENTITY_RESOURCE_GROUP} --query id -otsv)"
```
{{< figure src="img/managed_identity_assign.png" caption="assing managed identity to scale-set" >}}

```sh
# vytvoreni CR
cat <<EOF | kubectl apply -f -
apiVersion: "aadpodidentity.k8s.io/v1"
kind: AzureIdentity
metadata:
  name: $(echo ${IDENTITY_NAME}|tr '[:upper:]' '[:lower:]|tr '_' '-')
spec:
  type: 0
  resourceID: ${IDENTITY_RESOURCE_ID}
  clientID: ${IDENTITY_CLIENT_ID}
EOF  
```
```sh
cat <<EOF | kubectl apply -f -
apiVersion: "aadpodidentity.k8s.io/v1"
kind: AzureIdentityBinding
metadata:
  name: $(echo ${IDENTITY_NAME}-binding|tr '[:upper:]' '[:lower:]')
spec:
  azureIdentity: ${IDENTITY_NAME}
  selector: ${IDENTITY_NAME}
EOF 
```
Pro labeling v ramci deploye pouzijeme **aadpodidbinding** z hodnotou z **fieldu selector**
```yaml
      labels:
        aadpodidbinding: pod-identity
```

## ARGOCD install CUSTOMTOOLS (REPO-SERVER)
Pro ArgoCD bude potreba upravit deploy repo serveru tak aby obsahoval binárku SOPS a používal Managed Identity pro  
autentifikaci oproti AzureKV (sops key).  

{{< code file="ag-customtools.yaml" lang="yaml" >}}


## AZURE KV 
Vytvorime Azure KV a klic, priradime AccessPolicy pro vytvorenou MSI (UserManagedIdentitu)
{{< figure src="img/azureKV.png" caption="KV + AccessPolicy" >}}
{{< figure src="img/azureKV-key.png" caption="vytvoreni klice" >}}

## KOMFIGURACE MOZILLA SOPS
Zakladni konfigurace SOPS muze vypadat treba takto.

```sh
cat <<EOF >.sops.yaml
creation_rules:
# cesta ke klici
  - azure_keyvault: 'https://td-sops-keyvault.vault.azure.net/keys/sops-key1/e3499117c89b4d40ac6e651bc5e9f80b'
  # elementy pro encrypt
    encrypted_regex: "^(data)$"
EOF
```
```sh
cat <<EOF >secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: secret-name
type: Opaque
data:
  ahoj: cmFkIHRlIHZpZGlt
EOF
```
```sh
sops --encrypt secret.yaml
```

## ConfigManagementPlugins-ArgoCD
Konfigurace je ulozena v ConfigMap argocd-cm.  
Pro pridani pluginu
{{< code file="argocd-cm.yaml" lang="yaml" >}}

Myslenka je takova ze zakryptovane soubory budou mit koncovku .enc. V ramci loopy se vyctou jejich vysledek posle na STDOUT a je zpracovan jako  
kubectl apply -

```sh
# definice aplikace
kb port-forward argo-argocd-server-5d44f7f9f-mqlj9 8888:8080
argocd login 127.0.0.1:8888 --username admin --password 'argo-argocd-server-5d44f7f9f-g7q6b'
argocd app create sops --repo https://github.com/tomasdedic/sops.git --path . --dest-namespace default --dest-server https://kubernetes.default.svc --config-management-plugin sops
```

```yaml
# definice aplikace s pouzitim pluginu SOPS
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sops
  namespace: default
spec:
  destination:
    namespace: default
    server: https://kubernetes.default.svc
  project: default
  source:
    path: .
    plugin:
      name: sops
    repoURL: https://github.com/tomasdedic/sops.git
```

## TODO
1. pokud se pouzije plugin tak pak uz se dal neudela apply na zbyvajici manifesty ktere nejsou encrypted, chtelo by to nejake retezeni.  
Pripadne v init fazi pluginu vyrendrovat manifesty z .enc a v generate fazi je pak apply.
Stav je takovy ze se provede pouze ten plugin.
2. predani parametru z application.argoproj.io (potrebujeme vedet recursivitu)
```yaml
# tak takhle to nepujde
    plugin:
      name: sops
    env:
      - name: RECURSE
        valueFrom:
          fieldRef:
            fieldPath: spec.source.directory.recurse
```
3. prepsat mozilla sops tak aby pokuv v manifestu neni nic co by mel encryptovat tak pouze manifest print na stdout

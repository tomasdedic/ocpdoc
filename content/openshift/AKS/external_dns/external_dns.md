---
title: "External DNS, aad-pod-identity, cert-manager, nginx and enable ArgoCD to use ingress passthrough"
date: 2021-02-24
author: Tomas Dedic
description: "Desc"
lead: "working"
categories:
  - "AKS"
tags:
  - "DEPLOY"
---
Purpose of this excercise is to create automatic workflow.
Ingress resource will be able create A record in public DNS and get a TLS certificate for communication.

### Public DNS to Azure
Transfer DNS zone to Azure by creating DNS zone resource and use NS specified (differ  everytime)
```sh
dnszonerg='shared'
dnszonename='sudlice.org'
az network dns zone create -g $dnszonerg -n $dnszonename
# zadne A zaznamy tam ted nejsou
az network dns record-set a list -g $dnszonerg -z $dnszonename
```

### Install external Nginx
```sh
# install nginx
kubectl create namespace ingress-external
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm upgrade -i nginx-ingress-external ingress-nginx/ingress-nginx -n ingress-external --set controller.ingressClass=nginx-external --set --enable-ssl-passthrough=true
```

### Install AAD POD identity
Nakonfigurujeme **aad pod identity** tak aby propisoval UserManagedIdentitu nedefinovanou v Azure.
```sh
# AKS v azure pouziva kubenet
helm repo add aad-pod-identity https://raw.githubusercontent.com/Azure/aad-pod-identity/master/charts
helm install aad-pod-identity aad-pod-identity/aad-pod-identity --set nmi.allowNetworkPluginKubenet=true
# jedna replika nam staci
kb scale --replicas=1  deploy/aad-pod-identity-mic
```
Pouzijeme managed indentity prirazenou kubeletu v AKS.
```sh
aksname='opsdemoAKS'
aksrg='opsdemo'
dnszonerg='shared'
dnszonename='sudlice.org'
IDENTITY_CLIENT_ID=$(az aks show -n $aksname -g $aksrg --query identityProfile.kubeletidentity.clientId)
IDENTITY_RESOURCE_ID=$(az aks show -n $aksname -g $aksrg --query identityProfile.kubeletidentity.resourceId)
```
{{< code file="aad-pod-identity.yaml" lang="yaml" >}}

Pro labeling v ramci deploye pouzijeme label **aadpodidbinding** z hodnotou z **fieldu selector**. Deploy pak pouzije danou identitu. 
```yaml
      labels:
        aadpodidbinding: $selector 
```
Pro dalsi pouziti prez external dns priradime MSI prava nad DNS
```sh
# prirazeni prav pro managed identitu
# contributor pro DNS resource
az role assignment create --role "DNS Zone Contributor" \
    --assignee $(az aks show -n $aksname -g $aksrg --query identityProfile.kubeletidentity.clientId -o tsv)  \
    --scope $(az network dns zone show -g $dnszonerg -n $dnszonename --query id -o tsv)
# reader nad RG kde je DNS umisteno
az role assignment create --role "Reader" \
    --assignee $(az aks show -n $aksname -g $aksrg --query identityProfile.kubeletidentity.clientId -o tsv)  \
    -g $dnszonerg
```

### Install EXTERNAL DNS
When using external-dns with ingress objects it will automatically create DNS records based on host names specified in ingress objects that match the domain-filter argument in the external-dns deployment manifest. When those host names are removed or renamed the corresponding DNS records are also altered.
```sh
# query subscription parametes
az account show --query "tenantId" 
az account show --query "id" 

```
{{< code file="azure.json" lang="json" >}}
```sh
kubectl create secret generic azure-config-file --from-file=azure.json
```
{{< code file="external-dns-deploy.yaml" lang="yaml" >}}

### Install CERT MANAGER
```sh
helm repo add jetstack https://charts.jetstack.io
# Update your local Helm chart repository cache
helm repo update
# Install the cert-manager Helm chart
kb create namespace cert-manager
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v1.1.0 \
  --set installCRDs=true  
```
{{< code file="ClusterIssuer.yaml" lang="yaml" >}}

### Install ARGOCD
```sh
helm repo add argo https://argoproj.github.io/argo-helm
helm install argo argo/argo-cd --set installCRDs=false --set service.ingress.enabled=true
```
### Create Ingress Resource 
{{< code file="ingress-argocd.yaml" lang="yaml" >}}
```sh
#check dns record creation
az network dns record-set a list -g $dnszonerg -z $dnszonename
```

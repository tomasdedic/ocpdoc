---
title: "Instalace arga na AKS a infrastruktura pro demo"
date: 2021-01-08 
author: Tomas Dedic
description: "Desc"
lead: "working"
categories:
  - "AKS"
tags:
  - "ARGOCD"
---
# Instalace AKS
```sh
az login --tenant 67b7de17-01a8-410a-a645-3eacd61c1111 
az account list --output table
az account set --subscription "tdedic – MPN"
az group create --name opsdemo --location westeurope
az aks create -g opsdemo -n opsdemoAKS --node-count 1 --generate-ssh-keys --enable-managed-identity
az aks get-credentials --resource-group opsdemo --name opsdemoAKS --file ~/.kube/opsdemo
export KUBECONFIG=$HOME/.kube/opsdemo
```
# Ingress
```sh
# query for aks resource group
az aks show --resource-group opsdemo --name opsdemoAKS --query nodeResourceGroup -o tsv
az network public-ip create --resource-group MC_opsdemo_opsdemoAKS_westeurope --name AKSpubIP --sku Standard --allocation-method static --query publicIp.ipAddress -o tsv
# 20.73.33.192
helm install nginx-ingress ingress-nginx/ingress-nginx \
    --namespace ingress-basic \
    --set controller.replicaCount=1 \
    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set controller.service.loadBalancerIP="20.73.33.192" \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-dns-label-name"="pippo" \
    --set enable-ssl-passthrough=true
#query for fqdn
az network public-ip list --resource-group MC_opsdemo_opsdemoAKS_westeurope --query "[?name=='AKSpubIP'].[dnsSettings.fqdn]" -o tsv
```
# cert manager
```sh
# Label the cert-manager namespace to disable resource validation
kubectl label namespace ingress-basic cert-manager.io/disable-validation=true

# Add the Jetstack Helm repository
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

cat <<EOF|kb apply -n cert-manager -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: pippo@youcantlacthis.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
          podTemplate:
            spec:
              nodeSelector:
                "kubernetes.io/os": linux
EOF
# create certificate
cat <<EOF|kb apply -f - 
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: tls-secret
  namespace: ingress-basic
spec:
  secretName: tls-secret
  dnsNames:
  - pippo.westeurope.cloudapp.azure.com
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
EOF
```

# Instalace ARGOCD z oficialniho HELM chart
```sh
# ARGO_PWD=SUnxSPLmwqHrcdas
# htpasswd -nbBC 10 "" $ARGO_PWD | tr -d ':\n' |sed 's/$2y/$2a/'
helm repo add argo https://argoproj.github.io/argo-helm
cat <<EOF > values.yaml
installCRDs: false
EOF
helm install -f values.yaml --name argo argo/argo-cd

cat <<EOF |kb apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: default
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    kubernetes.io/ingress.class: nginx
    kubernetes.io/tls-acme: "true"
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
    # If you encounter a redirect loop or are getting a 307 response code 
    # then you need to force the nginx ingress to connect to the backend using HTTPS.
    #
    # nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  rules:
  - host: argocddemo.westeurope.cloudapp.azure.com
    http:
      paths:
      - backend:
          serviceName: argo-argocd-server
          servicePort: https
        path: /
  tls:
  - hosts:
    - argocddemo.westeurope.cloudapp.azure.com
    secretName: argocd-secret
EOF
```

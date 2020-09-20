---
title: konfigure AKS (Azure Kubernetes Service) pro DRMAX
date: 2019-08-05
author: Tomas Dedic
description: "konfigure AKS for DRMAx POC"
thumbnail: "img/14.jpg" # Optional, thumbnail
lead: "working"
disable_comments: true # Optional, disable Disqus comments if true
authorbox: false # Optional, enable authorbox for specific post
toc: false # Optional, enable Table of Contents for specific post
mathjax: false # Optional, enable MathJax for specific post
categories:
  - "DrMax"
tags:
  - "Azure"
  - "AKS"
menu: main # Optional, add page to a menu. Options: main, side, footer
sidebar: true
draft: false
---


# DEPLOYMENT KUBERNETES AZURE
```bash
export AKS_CLUSTER_NAME=drmax-poc
export RESOURCE_GROUP=DrMax_Kubernetes_Service
export ACR_NAME=drmaxacr
export LOCATION="westeurope"
export VNET_NAME="aks_vnet"
```
## NETWORK creation
**Virtual network:** The virtual network into which you want to deploy the Kubernetes cluster. If you want to create a new virtual network for your cluster, select Create new and follow the steps in the Create virtual network section. For information about the limits and quotas for an Azure virtual network, see Azure subscription and service limits, quotas, and constraints.

aks_vnet 172.17.0.0/23

**Subnet:** The subnet within the virtual network where you want to deploy the cluster. If you want to create a new subnet in the virtual network for your cluster, select Create new and follow the steps in the Create subnet section. For hybrid connectivity, the address range shouldn't overlap with any other virtual networks in your environment.

default 172.17.0.0/24

```bash
set SUBNET_ID (az network vnet subnet list \
    --resource-group $RESOURCE_GROUP \
    --vnet-name aks_vnet \
    --query [].id --output tsv)

#network plugin azure je dulezity abychom mohli dat AKS do vnety
az aks create \
    --resource-group $RESOURCE_GROUP  \
    --name $AKS_CLUSTER_NAME \
    --network-plugin azure \
    --vnet-subnet-id $SUBNET_ID \
    --docker-bridge-address 172.16.0.1/16 \
    --dns-service-ip 10.2.0.10 \
    --service-cidr 10.2.0.0/24 \
    --generate-ssh-keys
```

## BASE CONFIG (ACR and AKS)
```sh
export AKS_CLUSTER_NAME=drmax-poc
export RESOURCE_GROUP=DrMax_Kubernetes_Service
export ACR_NAME=drmaxacr
export LOCATION="westeurope"

az login
# pokud mame vice subscriptions
az account set --subscription "SUBSCRIPTION-NAME"
# vytvorit resource groupy pokud neexistuje
az group create --name ${RESOURCE_GROUP} -rg --location ${LOCATION}

#create ACR (azure container registry)
az acr create --name ${ACR_NAME} --resource-group ${RESOURCE_GROUP} --sku Standard --location ${LOCATION} --admin-enabled true
	# Get ACR_URL for future use with docker-compose and build
	export ACR_URL=$(az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query "loginServer" --output tsv)
	echo $ACR_URL
	#drmaxacr.azurecr.io

	# Get ACR key for our experiments
	export ACR_KEY=$(az acr credential show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query "passwords[0].value" --output tsv)
	echo $ACR_KEY
```
Install kubectl, the Kubernetes command-line interface, and configure it with the credentials for the new AKS cluster:

```bash
az aks get-credentials --name $AKS_CLUSTER_NAME --resource-group $RESOURCE_GROUP

#pokud jsme meli predtim AKS cluster se stejnym nazvem
>A different object named drmax-poc already exists in clusters 
#je potreba ho smazat z ~/.kube/config
# patch kubernetes configuration to be able to access dashboard
kubectl create clusterrolebinding kubernetes-dashboard \
  -n kube-system --clusterrole=cluster-admin \
  --serviceaccount=kube-system:kubernetes-dashboard
```

**run dashboard:**
```
az aks browse --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME
```

## Setup access for AKS to ACR
```bash
# Get the id of the service principal configured for AKS
export CLIENT_ID=$(az aks show --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME --query "servicePrincipalProfile.clientId" --output tsv)
#fish shell
set CLIENT_ID (az aks show --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME --query "servicePrincipalProfile.clientId" --output tsv)

# Get the ACR registry resource id
export ACR_ID=$(az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query "id" --output tsv)
#fish shell
set ACR_ID (az acr show --name $ACR_NAME --resource-group $RESOURCE_GROUP --query "id" --output tsv)

# Create role assignment
az role assignment create --assignee $CLIENT_ID --role Reader --scope $ACR_ID
```
## BUILD image in Azure Container Registry
My environment runs in fish shell but scripts are in bash.

```sh
#local build
docker build -f Dockerfile -t date-server .
bass 'source ./setenvironment.sh'
az acr build --registry $ACR_NAME --image shell2http:v1 ./Docker/shell2http
kubectl apply -f 01-shell2http-deploy.yaml
#and service to access from outside
kubectl apply -f 02-shell2http-loadbalancer-service.yaml
```

## Install And Configure Helm And Tiller
*So Helm is our package manager for Kubernetes and our client tool. We use the helm cli to do all of our commands. The other part to this puzzle is Tiller.
Helm uses a packaging format called charts. A chart is a collection of files that describe a related set of Kubernetes resources. A single chart might be used to deploy something simple or something complex.
Tiller is the service that actually communicates with the Kubernetes API to manage our Helm packages.*
  
Configur Helm to work in your AKS cluster and provided Tiller the right permissions to allow Helm to deploy charts with RBAC.
Install and configure Helm for your operating system and then create the following Kubernetes objects to make Helm work with Role-Based Access Control (RBAC) in AKS:
  
ClusterRoleBinding
ServiceAccount
  
To install Helm, run the following commands:
```bash
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh
```
To create a ServiceAccount and associate it with the predefined cluster-admin role, use a ClusterRoleBinding, as below:
```bash
kubectl create serviceaccount -n kube-system tiller #in namespace kube-system
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
```
Initialize Helm as shown below:
```bash
helm init --service-account tiller
If you have previously initialized Helm, execute the following command to upgrade it:

helm init --upgrade --service-account tiller
```
**prez yaml**  
Create account in Kubernetes for Helm, install server-side component and check it.
```bash
# Create a service account for Helm and grant the cluster admin role.
kubectl apply -f helm-account.yaml
# initialize helm
helm init --service-account tiller --upgrade
# after while check if helm is installed in cluster
helm version
```

## NGINX INGRESS CONTROLLER
```sh
helm install --name ingress stable/nginx-ingress \
  --set rbac.create=true \
  --set controller.image.tag=0.21.0

export INGRESS_IP=$(kubectl get service ingress-nginx-ingress-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
http://${INGRESS_IP}.xip.io
```
## USE MSSQL PaaS
```sh
export SQL_SERVER_NAME="sqldb-drmax"
export SQL_USER="myadmin"
export SQL_PASSWORD="manager123%"
export SQL_DATABASE_NAME="drmaxdb"

az sql server create --resource-group ${RESOURCE_GROUP} \
  --name ${SQL_SERVER_NAME}  --location ${LOCATION} \
  --admin-user ${SQL_USER} --admin-password ${SQL_PASSWORD}

# Get SQL FQDN (we will need in later on for configuration)
export SQL_FQDN=$(az sql server show --resource-group ${RESOURCE_GROUP} --name ${SQL_SERVER_NAME} --query "fullyQualifiedDomainName" --output tsv)
echo $SQL_FQDN

# create SQL database in Azure
az sql db create --resource-group ${RESOURCE_GROUP} \
  --server ${SQL_SERVER_NAME}   \
  --name ${SQL_DATABASE_NAME}

# enable access for Azure resources (only for services running in azure)
az sql server firewall-rule create \
  --server-name ${SQL_SERVER_NAME} \
  --resource-group ${RESOURCE_GROUP} \
  --name "AllowAllAzureIps" --start-ip-address "0.0.0.0" --end-ip-address "0.0.0.0"
```
TEST from pod if database is alive
```bash
nc -zv $SQL_FQDN 1433
```

## Pull image from DockerHub in AKS 
hub.docker.com je trochu tricky
```bash
To pull a private DockerHub hosted image from a Kubernetes YAML:

Run these commands:

export DOCKER_REGISTRY_SERVER=docker.io
export DOCKER_USER=dedtom
export DOCKER_EMAIL=spratek@gmail.com
export DOCKER_PASSWORD=star2996

kubectl create secret docker-registry myregistrykey \
  --docker-server=$DOCKER_REGISTRY_SERVER \
  --docker-username=$DOCKER_USER \
  --docker-password=$DOCKER_PASSWORD \
  --docker-email=$DOCKER_EMAIL

spec pro kontejner pak upravit jako

  containers:
    - name: whatever
      image: DOCKER_USER/PRIVATE_REPO_NAME:latest
      imagePullPolicy: Always
      command: [ "echo", "SUCCESS" ]
  imagePullSecrets:
    - name: myregistrykey
```

## USE AZUREFILES AS Fileshare
Moje puvodni myšlenka byla že udělám NFS servere jako standalone VM, nastal však problém s naší subskripcí kdy můžeme používat jen 10 vCPU a již nejsou.
Řešení bude tedy že pro sdílení souborů použijeme AzureFile.
1. AzureFile umožňuje RWMANY
2. AzureFile je přez SMB můžeme mountovat rovnou ke každému podu

AzureFile requires five things to work:
+ secret
+ storageclass definition
+ volume attachement to deployment (or a persistentvolume globally if you'd like to use one share for many things )
+ defined share that will be available to attach (that share must exist - it won't be automatically created)
+ Firewalls must have port 455/tcp opened in order to establish communication between cluster and azure storage service
>If you have multiple Pods of the same image (multiple replicas) that form a group that work together and you want to mount a volume per Pod to write data to. You may want to use StateFull Set.

```bash
Create storage account

export STORAGE_ACCOUNT_NAME=drmaxstore
export STORAGE_ACCOUNT_SHARE=drmaxshare

az storage account create --resource-group ${RESOURCE_GROUP} --kind Storage --name ${STORAGE_ACCOUNT_NAME}
#export STORAGE_ACCOUNT_KEY
export STORAGE_ACCOUNT_KEY=$(az storage account keys list -g ${RESOURCE_GROUP} -n ${STORAGE_ACCOUNT_NAME} --output tsv|awk 'NR==1{print $3}')
#for fish shell -- sory I love fish shell
set  STORAGE_ACCOUNT_KEY (az storage account keys list -g {$RESOURCE_GROUP} -n {$STORAGE_ACCOUNT_NAME} --output tsv|awk 'NR==1{print $3}')


Create fileshare
#quota in GB
az storage share create --account-name $STORAGE_ACCOUNT_NAME --account-key $STORAGE_ACCOUNT_KEY --name $STORAGE_ACCOUNT_SHARE  --quota 100

kubectl create secret generic drmaxfilestore-secret --from-literal azurestorageaccountname=$STORAGE_ACCOUNT_NAME  --from-literal azurestorageaccountkey=$STORAGE_ACCOUNT_KEY  --type=Opaque
```
```yaml
#jelikož kubernetes nemá storageclass pro azurefile tak vytvořime
---
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: azurefile
provisioner: kubernetes.io/azure-file
mountOptions:
  - dir_mode=0775
  - file_mode=0775
  - uid=1000
  - gid=1000
  - mfsymlinks
  - nobrl
  - cache=none
parameters:
  storageAccount:drmaxstore  # $STORAGE_ACCOUNT_NAME
  skuName: Standard_LRS
	resourceGroup: DrMax_Kubernetes_Service # $RESOURCE_GROUP

```
a upravime image
```yaml
        volumeMounts:
        - name: azurefilestore      #reference to spec.volumes.name
          mountPath: /share   #path where it should be mounted
      volumes:
          - name: azurefilestore
            azureFile:
              secretName: drmaxfilestore-secret    #reference to deployed azure-secret file
              shareName: drmaxshare
              readOnly: false
```

## ConfigMAPS for configuration of EAP
Trochu mi vadí že pokud něco změnim v konfiguráku pro jboss musím udělat build celého kontejneru. Přijde mi fajn použít kubernetes configmaps pro config v /config/standalone/configuration.
Problém config map je že nejde mít prezentovaný jen jeden soubor, resp lze ale je nutné ho prezentovat do volume.
```bash
#copy data from kubernetes pod to local

kubectl cp eap-7c58bf55d-zhjnt:/config/standalone/configuration/ ./configuration/
```
create config map
```bash
kubectl create configmap configuration --from-file=./configuration/
```
a upravime deploy definici
```yaml
#konfigurace bude ulozena /etc/config/configuration
        volumeMounts:
        - name: config-volume
          mountPath: /etc/config/configuration
      volumes:
          - name: config-volume
            configMap:
              name: configuration
#pokud chceme pouzit jen jeden soubor
volumes:
    - name: config-volume
      configMap:
        name: configuration
        items:
        - key: standalone.xml #kubectl describe configmap configuration
          path: standalone.xml #jak bude prezentovana na FS
```
## RESOURCES for CONTAINER
Jelikož problém se startováním EAP byl způsoben omezenými resourci v definici kontejneru
je čas se tomu podívat trochu na zoubek.

4 typy resourcu:
spec.containers[].resources.limits.cpu
spec.containers[].resources.limits.memory
spec.containers[].resources.requests.cpu
spec.containers[].resources.requests.memory

```yaml
#kazdy container dostane 0.5 VCPU a limit bude 6GB a request (pro pod scheduler) bude 3GB, tyhle parametry nedelaji strop jen urcuji kolik by mel mit zdroju
          limits:    # Always limit resources to keep nodes healthy (eg. prevent memory leak to hurt other containers)
            cpu: 500m
            memory: 6144M
          requests:     # Always define request so scheduler can decide better about placements (required for node autoscaling)
            cpu: 500m
            memory: 3072M
```

## READINESS a LIVENESS PROBES
V podstatě znamená za jak dlouho bude označen jako připraven přijímat requesty - bude označen jako READY. A zda žije tzn pokud nebude vracet hodnotu bude označen jako KO a vyřazen z AKS a vytvořen nový.
Zatim jsem se spokojil s voláním přez shell ale HTTP request by byl lepší.

```yaml
        livenessProbe:
          exec:
            command:
              - /bin/sh
              - -c
              - /opt/jboss/bin/jboss-cli.sh --connect --commands=ls | grep 'server-state=running'
          initialDelaySeconds: 150
          periodSeconds: 20
          timeoutSeconds: 5
        readinessProbe:
          exec:
            command:
              - /bin/sh
              - -c
              - /opt/jboss/bin/jboss-cli.sh --connect --commands='ls deployment' | grep 'B2B'
          initialDelaySeconds: 200
          periodSeconds: 20
          timeoutSeconds: 5
```

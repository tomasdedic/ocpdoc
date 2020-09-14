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

az aro delete --resource-group $RESOURCEGROUP --name $CLUSTER


az network nic ip-config create --name sec1 --nic-name arozinite-r4ttx-worker-westeurope1-wf7jj-nic --private-ip-address 10.10.11.1 --resource-group aro-t6sjpdhb


{
"kubeadminPassword": "8yLjU-rpEvQ-gmEJv-A8b84",
"kubeadminUsername": "kubeadmin"
"api": "https://api.t6sjpdhb.westeurope.aroapp.io:6443/"
"console": "https://console-openshift-console.apps.t6sjpdhb.westeurope.aroapp.io/"
}

{- Finished ..
  "apiserverProfile": {
    "ip": "20.50.213.192",
    "url": "https://api.t6sjpdhb.westeurope.aroapp.io:6443/",
    "visibility": "Public"
  },
  "clusterProfile": {
    "domain": "t6sjpdhb",
    "pullSecret": null,
    "resourceGroupId": "/subscriptions/7504de90-f639-4328-a5b6-fde85e0a7fd9/resourceGroups/aro-t6sjpdhb",
    "version": "4.4.10"
  },
  "consoleProfile": {
    "url": "https://console-openshift-console.apps.t6sjpdhb.westeurope.aroapp.io/"
  },
  "id": "/subscriptions/7504de90-f639-4328-a5b6-fde85e0a7fd9/resourceGroups/aro-test/providers/Microsoft.RedHatOpenShift/openShiftClusters/arozinite",
  "ingressProfiles": [
    {
      "ip": "51.105.237.82",
      "name": "default",
      "visibility": "Public"
    }
  ],
  "location": "westeurope",
  "masterProfile": {
    "subnetId": "/subscriptions/7504de90-f639-4328-a5b6-fde85e0a7fd9/resourceGroups/aro-test/providers/Microsoft.Network/virtualNetworks/aro-vnet/subnets/master-subnet",
    "vmSize": "Standard_D8s_v3"
  },
  "name": "arozinite",
  "networkProfile": {
    "podCidr": "10.128.0.0/14",
    "serviceCidr": "172.30.0.0/16"
  },
  "provisioningState": "Succeeded",
  "resourceGroup": "aro-test",
  "servicePrincipalProfile": {
    "clientId": "e4346940-23f1-41f6-8a39-0c09b7e54225",
    "clientSecret": null
  },
  "tags": null,
  "type": "Microsoft.RedHatOpenShift/openShiftClusters",
  "workerProfiles": [
    {
      "count": 1,
      "diskSizeGb": 128,
      "name": "arozinite-r4ttx-worker-westeurope1",
      "subnetId": "/subscriptions/7504de90-f639-4328-a5b6-fde85e0a7fd9/resourceGroups/aro-test/providers/Microsoft.Network/virtualNetworks/aro-vnet/subnets/worker-subnet",
      "vmSize": "Standard_D4s_v3"
    },
    {
      "count": 1,
      "diskSizeGb": 128,
      "name": "arozinite-r4ttx-worker-westeurope2",
      "subnetId": "/subscriptions/7504de90-f639-4328-a5b6-fde85e0a7fd9/resourceGroups/aro-test/providers/Microsoft.Network/virtualNetworks/aro-vnet/subnets/worker-subnet",
      "vmSize": "Standard_D4s_v3"
    },
    {
      "count": 1,
      "diskSizeGb": 128,
      "name": "arozinite-r4ttx-worker-westeurope3",
      "subnetId": "/subscriptions/7504de90-f639-4328-a5b6-fde85e0a7fd9/resourceGroups/aro-test/providers/Microsoft.Network/virtualNetworks/aro-vnet/subnets/worker-subnet",
      "vmSize": "Standard_D4s_v3"
    }
  ]
}

# POPIS INSTALACE OPENSHIFT 4.x stable build v prostředí Azure
Popis instalace OpenShift ve verzi 4.x jako publish Internal tedy s definicí endpointů do private zóny.
## Přípravné kroky
### Private DNS zone
Při instalaci je potřeba nakonfigurovat automaticky vytvořenou **private DNS zone** tak že k ní budou přilinkovány Azure Vnet.  
Privatni DNS zona se nechova jako klasicky DNS server, nemá IP adresy na které by se dala
forwardnout z jinych DNS serveru.
Zaznamy z ní muzou resolvnout pouze VM umisteny v Azure Vnet, která je přilinkovaná k
private DNS zóně a to pouze za předpokladu že pro resolvování záznamu v těchto zónách
používají Azure DNS server (168.63.129.16)  

V Azure je pro přilinkování vytvořena policy která by měla během cca 10 minut provést přilinkování potřebných vnet k vytvořené private DNS zóně.  
Konfigurace by pak měla vypadat následovně:
{{< figure src="img/virtual_network_link-proprivateDNS.png" caption="privateDNS virtual-network-links" >}}

### Příprava Azure účtu a service principals

```sh
az login
az account show
 #define service principals
az ad sp create-for-rbac --name service_principal_name
 #add roles
az role assignment create --assignee "app id of service principal" --role Contributor --output none
az role assignment create --assignee "app id of service principal" --role "User Access Administrator" --output none
 # service principal needs read write owned by app permisions azure AD graph
az ad app permission add --id "app id of service principal" \
-- api 00000002-0000-0000-c000-000000000000 \
-- api-permissions 824c81eb0e3f8-4ee6-8f6d-de7f50d565b7-Role
 #subscription id
az account list --output table
 #tenant id --> when create service principals
 #service principal client id -->app id when created service principal
 # service principal client secret -->output of service principal
```
### Redhat pull secret
Redhat pull secret získáme z [(redhat-pull-secret)](https://cloud.redhat.com/openshift/install/azure/installer-provisioned)

### Konfigurační soubory Azure
Pro service principals vytvoříme soubor *~/.azure/osServicePrincipal.json* s obsahem dle vytvořeného service principal s následující strukturou:
```sh
touch ~/.azure/osServicePrincipal.json
{"subscriptionId":"7504de90-f639-4328-a5b6-fde85e0a7fd9","clientId":"126501b0-ae03-4aad-aff2-19ced106b169","clientSecret":"********","tenantId":"d2480fab-7029-4378-9e54-3b7a474eb327"}
```
Pro různé instalace do stejné subskripce můžeme využít stejné service principals.

Adresář *~/.azure* pak bude vypadat následovně:
```sh
.azure/
├── accessTokens.json
├── azureProfile.json
└── osServicePrincipal.json
```
### SSH klíče
Vytvoříme ssh klíče pro přístup na jednotlivé nody OCP. 
```sh
ssh-keygen -f $HOME/.ssh/id_dsa -t dsa -b 1024
chmod 700 ~/.ssh
```
### Create Azure Vnet and Install with existing VNET
> předpokládáme instalaci do existujících VNET je tedy potřeba pouze zkontrolovat nastavení NSG

Vytvořit Azure Vnet s dvěmi **subnety** (jednu pro master nody a jednu pro worker nody).
{{< figure src="img/vnet-definition.png" caption="vnet definition" >}}
  
Pro každou subnet vytvořit NSG(network security group) a přiřadit příslušným subnet. Hlavní důvod je ssh přístup na bootstrap VM, z kterého instalátor pracuje.  
*Pozn: Při instalaci se NSG vytvoří automaticky v resource_group OCP objektů jen se nepřiřadí Subnetu, lze tedy použít i tu. Pokud se tak rozhodnete je potřeba to provést v průběhu instalace (provisioning objektů v Azure se dělá jako první).*  

{{< figure src="img/masterNSG.png" caption="NSG pro master nodes" >}}
{{< figure src="img/workerNSG.png" caption="NSG pro worker nodes" >}}

yaml defince vnet(v samostatné RG)resouce_group:
```yaml
# install-config.yaml snippet
	poshi_vnet_rg
vnet:
	poshi_vnet 10.2.0.0/16
subnet:
	poshi-worker-subnet 10.2.32.0/19
	poshi-master-subnet 10.2.0.0/19
```
## Síťové prostupy
Instalace se provádí v topologii HUB_and_SPOKE se předkonfigurovaným routingem(route table ve VNET) , z pohledu Openshiftu UserDefinedRouting.  
Pro instalaci v privátní zóně by měla být veškerá komunikace mimo privátní rozsah směrována přez proxy. Ne všechny kontejnery však přejímají nastavení CRD proxy.config jako ENV variable a je potřeba povolit komunikaci na VSEC GW. 

|domény povolené na VSEC GW|
|--------------------------|
|.blob.core.windows.net    |
|login.microsoftonline.com |
|management.azure.com      |
|168.63.129.168            |

## Konfigurace cluster-wide proxy
Jako proxy bude použita:  
```sh
httpProxy: http://ngproxy-test.csint.cz:8080
httpsProxy: http://ngproxy-test.csint.cz:8080
```

```yaml
apiVersion: config.openshift.io/v1
kind: Proxy
metadata:
  generation: 2
  name: cluster
spec:
  httpProxy: http://adresa:port
  httpsProxy: https://adresa:port
  noProxy: 
  trustedCA:
    name: ""
status:
  httpProxy: http://adresa:port
  httpsProxy: https://adresa:port
  noProxy: .cluster.local,.svc,10.0.0.0/16,10.128.0.0/14,127.0.0.1,169.254.169.254,172.30.0.0/16,api-int.{cluster.dns.zone},
           etcd-0.{cluster.dns.zone},etcd-1.{cluster.dns.zone},etcd-2.{cluster.dns.zone},localhost
```
Jako noProxy, tedy whitelisting by bylo vhodné uvést důvěryhodné zdroje které OCP vyžaduje ke svému běhu.  

| ADRESS                           |    DESCRIPTION     |
|--------------------------------  |:-------------------|
|registry.redhat.io							   |		Provides core container images|
|*.quay.io												   |		Provides core container images|
|sso.redhat.com									   |		The https://cloud.redhat.com/openshift site uses authentication from|
|cert-api.access.redhat.com			   |		Required for Telemetry|
|api.access.redhat.com						   |		Required for Telemetry|
|infogw.api.openshift.com				   |		Required for Telemetry|
|management.azure.com						   |		Azure services and resources|
|mirror.openshift.com			  		   |		Required to access mirrored installation content and images|
|*.cloudfront.net					  		   |		Required by the Quay CDN to deliver the Quay.io images that the cluster requires|
|*.apps.<cluster_name>.<base_domain>| Required to access the default cluster routes unless you set an ingress wildcard during installation|
|api.openshift.com									 |	Required to check if updates are available for the cluster|
|cloud.redhat.com/openshift				 |	Required for your cluster token|

##  Instalace typu "INTERNAL" do private zóny
Rozdíl mezi intalací typu Internal a External je pouze v publikaci endpointů.

Stáhneme a rozbalíme balíky *openshift-client, openshift-install*.
+ [(stable installer)](https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/)
+ [(dev preview installer)](https://mirror.openshift.com/pub/openshift-v4/clients/ocp-dev-preview/)  
Při instalaci dev preview nebudou fungovat upgrady na vyšší verze.
  
[link na custom properties](https://github.com/openshift/installer/blob/master/docs/user/customization.md#platform-customization)  
[link na azure platform properties](https://github.com/openshift/installer/blob/master/docs/user/azure/customization.md)  

```sh
# jednotlivé elementy použitelné pro install-config.yaml lze vypsat 
openshift-install explain installconfig
```

```sh
# necháme si vygenerovat konfigurační soubor který budeme dál upravovat
openshift-install create install-config --dir ./install_dir --log-level debug
```

### Použití Artifactory jako container registry
Pro instalaci a používání OCP v privátní síti bude jako zdroj všech kontejnerů využita Artifactory. Všechny remote repository (vnější) budou whitelistovány přez ní a bude pro ně vytvořena konfigurace.  
[link: artifactory_as_proxy_for_containerregistries obecně](/openshift/artifactory_as_proxy_for_containerregistries/)  
[link: artifactory_as_proxy_for_containerregistries uprava install-config.yaml](/openshift/artifactory_as_proxy_for_containerregistries/#použití-remote-repository-při-instalaci-ocp-quayio-repository)


### Instalační soubor INSTALL-CONFIG.YAML
následně upravíme vygenerovaný ~/install_dir/install-config.yaml, důležité části jsou s komentáři
{{< code file="src/install-config.yaml" lang="yaml" >}}

### Spuštění instalace a případný debug
```sh
 # install 
openshift-install create cluster --dir ./install_dir --log-level debug
 # openshift vytvoří svojí resource group v subskripci
  INFO Waiting up to 30m0s for the cluster at https://api.DNS:6443 to initialize...
  INFO Waiting up to 10m0s for the openshift-console route to be created...
  INFO Install complete!
```
```sh
# test
export KUBECONFIG=$(pwd)/install_dir/auth/kubeconfig
oc login --username=kubeadmin --password='password'
oc get clusterversion
oc get nodes
oc get clusteroperators
 # konfigurace a její uložení na FS, tento krok není nutný
oc adm must-gather
```

```sh
# bootstrap server debug
openshift-install gather bootstrap --bootstrap 51.124.79.94 --master 51.124.94.42
openshift-install gather bootstrap
```
```sh
# bootstrap journal logs
journalctl -b  -u release-image.service -u bootkube.service|grep -E "E[[:digit:]]{4}"
journalctl -b -f -u release-image.service -u bootkube.service
 # grep all https://
for i in $(find . -name \*.log); do cat $i|grep http; done|grep -Eo "https:\/\/[[:graph:]]*"
```

### Uninstall proces
```sh
openshift-install destroy cluster --dir ./install_dir --log-level debug
```
Provision části které vytvořil OCP při instalaci budou smazány (týká se to jeho vlastní RG v Azure)


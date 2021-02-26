# Openshift tasks roadmap


## IPI instalace s UDR

**dokumenty:**
+ [instalace OCP v prostředí Azure](/openshift/install/instalaceazure/)
+ [konfigurace PROXY](/openshift/install/nastaveni_proxy/)
+ [Artifactory jako container registry v izolovaném prostředí](/openshift/artifactory_as_proxy_for_containerregistries/)

**tasks:**
+ [x] Reinstall clusteru oaz-dev na stabilní větev 4.6
+ [x] [**Stabilita Openshift-api serveru**](/openshift/debug/openshiftapiserver-tls/)  
+ [x] Pretezovani kubeletu

## Integrace AAD a LDAP group sync 
Test autentizace oproti AAD v testovacím prostředí, LDAP sync pro dotažení skupin z AD a definice rolí.
+ [x] [OpenID connect oproti AAD v Sandbox prostředí](/openshift/openid-provider/)
+ [x] [OpenID connect oproti TEST AAD CSAS] 
+ [x] [LDAP group sync - pouziti AAD group sync operator] 

## Ingres více routerů, route sharding

+ [ ] route sharding + logika přidělování ingres controlerů jednotlivým namespacům (řešené labelem a vytvoření resource přez ArgoCD)
+ [ ] test zda lze použít stejnou adresu pro ingres i egres

## Egress
+ [ ] [neni dořešeno přidělování adres na nódy jinak než manuálně při jejich vzniku](/openshift/ingress-egress/egress-problemy_s_pridelovanim_adres-azure/)
The egress IP address implementation is not compatible with Amazon Web Services (AWS), Azure Cloud, or any other public cloud platform incompatible with the automatic layer 2 network manipulation required by the egress IP feature"

## Network policy/netnamespace isolation
+ network policy řeší CSAS project operator při zakládání namespace (projektu)

## Monitoring stack
via Elostech, dodávka by měla reflektovat nasazení pomocí ArgoCD.

## Logging stack(/categories/logging/)
[Logging stack overall](/categories/logging/)

+ [ ] Validace změn v openshift-aggregate logging. Chybí dodefinovat přesné požadavky na formát a směrování logů z Openshiftu ven. 
Základní POC je hotov, logy jsou transformováný a směrovány do lokální instance ElasticSearch, část je směrována do Azure EventHubu pomocí FluentD kafka plugin
+ [ ] Instalace samotného ElasticSearch
+ [ ] Použití logging API

## Complience operator

## Non Root buildy

## Security

+ [x] [Šifrování disků a ETCD](/openshift/encryption_azure_summary/)
+ [x] [Service principals vytvářené Openshiftem v Azure](/openshift/service-principal/)
+ [ ] [Open policy agent ve vazbě k zakládaným resourcům]

## Systémové věci nasazované přez Argo

+ [ ] [Tuned operator]
+ [ ] [NTP definice onprem/Azure]
+ [ ] [Azure ARM resources]


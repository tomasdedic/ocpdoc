# Openshift tasks roadmap


## IPI instalace s UDR

**dokumenty:**
+ [instalace OCP v prostředí Azure](/openshift/install/instalaceazure/)
+ [konfigurace PROXY](/openshift/install/nastaveni_proxy/)
+ [Artifactory jako container registry v izolovaném prostředí](/openshift/artifactory_as_proxy_for_containerregistries/)

**tasks:**
+ [ ] Reinstall clusteru oaz-dev na stabilní větev 4.6

+ [x] [**Stabilita Openshift-api serveru**](/openshift/debug/openshiftapiserver-tls/)  
Po předem nedefinované době zdroje poskytované openshift-api serverem jsou částečně nedostupné, objevují se chyby **HTTP 503** . Openshift-api server operátor je nevalidní  
**Problém se objevuje na instalacích řady 4.6.**

## Integrace AAD a LDAP group sync 
Test autentizace oproti AAD v testovacím prostředí, LDAP sync pro dotažení skupin z AD a definice rolí.
+ [x] [OpenID connect oproti AAD v Sandbox prostředí](/openshift/openid-provider/)
+ [x] [OpenID connect oproti TEST AAD CSAS] 
+ [ ] LDAP sync

## Ingres více routerů, route sharding

+ [ ] route sharding + logika přidělování ingres controlerů jednotlivým namespacům (řešené labelem a vytvoření resource přez ArgoCD)
+ [ ] test zda lze použít stejnou adresu pro ingres i egres

## Egress
+ [ ] [neni dořešeno přidělování adres na nódy jinak než manuálně při jejich vzniku](/openshift/ingress-egress/egress-problemy_s_pridelovanim_adres-azure/)

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


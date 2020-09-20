## TO BE DONE LIST

### IPI instalace s UDR

**dokumenty:**
+ [/instalaceAzure/](/openshift/instalaceazure/)

**řešené problémy:**
> Vyřešeno použitím instalace linux-4.6.0-0.nightly-2020-08-18-070534

+ [x] **Instalátor musí obsahovat**  
```sh
	./openshift-install explain installconfig.platform.azure
	    outboundType <string>
	      Default: "Loadbalancer"
	      Valid Values: "","Loadbalancer","UserDefinedRouting"
	      OutboundType is a strategy for how egress from cluster is achieved. 
        When not specified default is "Loadbalancer".
```
Tato možnost je validní pouze pro instalátory řady 4.6.x

+ [x] **Stabilita Openshift-api serveru**  
Po předem nedefinované době zdroje poskytované openshift-api serverem jsou částečně nedostupné, objevují se chyby **HTTP 503** . Openshift-api server operátor je nevalidní
```sh
 # example
oc get clusteroperator
  NAME                    VERSION                             AVAILABLE   PROGRESSING   DEGRADED   SINCE
  authentication          4.6.0-0.nightly-2020-07-24-111750   True        False         True       5d19h
  image-registry          4.6.0-0.nightly-2020-07-24-111750   True        False         True       6d20h
  monitoring              4.6.0-0.nightly-2020-07-24-111750   False       True          True       35h
  openshift-apiserver     4.6.0-0.nightly-2020-07-24-111750   False       False         False      18h
```
Problém se objevuje na instalacích řady 4.6.

### Integrace AAD  a LDAP group sync 
Test autentizace oproti AAD v testovacím prostředí, LDAP sync pro dotažení skupin z AD a definice rolí.
+ [ ] přístup do Test AD
+ [ ] testovací uživatelé v AAD

### Ingres více routerů, route sharding

+ [ ] route sharding + logika přidělování ingres controlerů jednotlivým namespacům (řešené labelem a vytvoření resource přez ArgoCD)
+ [ ] test zda lze použít stejnou adresu pro ingres i egres

### Egress
premisa: **Není možné použít jednu egress IP pro více namespaců.**  
Egress z pohledu Azure VM není vyřešen. Na jednotlivých nódech se interface s požadovanou IP adresou vytvoří ale na Azure VM se nevytvoří secondaryIP adresa nad NIC a požadavky nejsou tedy routovány ven.  
Ideální řešení by bylo dynamické přidělování Egress adres na jednotlivé nódy, v případě nedostupnosti nódu automatický failover na jiný nód, vyžadovalo by to však operátor který by byl schopen sledovat stavy systému jak z pohledu Azure tak z pohledu OCP a na základě vyhodnocení provést požadovanou akci. Operátor by tak měl velké množství stupňů volnosti a nejsem si jist zda jsme schopni zajistit v rozumném vývojovém čase kvalitní chování.  


**When a namespace has multiple egress IP addresses, if the node hosting the first egress IP address is unreachable, OpenShift Container Platform will automatically switch to using the next available egress IP address until the first egress IP address is reachable again.**  
obecný proces :  
+ rozdělit pool egress adres podle zón, tedy na 3 CIDR
+ přidělit takto vydefinované CIDR (hostsubnet) rozsahy vybraným nódům (1 na každou zónu)
+ pro každý CIDR, jedna IP adresa je vybrána a přiřazena "namespacu"
+ nakonfiguruje se relevantní "netnamespace" vydefinovanými IP adresami (budou mu přiděleny 3 adresy)
+ jeden nód pro každou zónu tak bude mít nadefinovanou EgressIP 
+ na Azure VM bude pro takový nód vydefinována secondaryIP s hodnotou EgressIP


Možnosti jsou v podstatě následující:  
+ [Egressip-ipam-operator](https://github.com/redhat-cop/egressip-ipam-operator)
	Upravit operátor pro Azure, v tento okamžik podporuje pouze AWS. Operátor zpravuje k Egress jako CRD přímo v Openshiftu. 

+ EgressGateway nody  
	**When a namespace has multiple egress IP addresses, if the node hosting the first egress IP address is unreachable, OpenShift Container Platform will automatically switch to using the next available egress IP address until the first egress IP address is reachable again.**
  Nadefinovat egress nody (minimálně dva) a přidělit jim egress adresy dle přidělených IP, každému namespacu pak přidělit dvě adresy.  Při této konfiguraci však přijdeme o půlku IP adres pro Egresy.

### Network policy/netnamespace isolation
Zatím není nadefinováno jakým způsobem se k tomuto problému postavíme. Jako logický krok se jeví **multitenant isolation** - tedy v základu žádný workload namespace nevidí síťově jiný.

### Monitoring stack
via Elostech, dodávka by měla reflektovat nasazení pomocí ArgoCD.

### Logging stack
Validace změn v openshift-aggregate logging. Chybí dodefinovat přesné požadavky na formát a směrování logů z Openshiftu ven. 
Základní POC je hotov, logy jsou transformováný a směrovány do lokální instance ElasticSearch, část je směrována do Azure EventHubu pomocí FluentD kafka plugin

## VYŘEŠENÉ ČÁSTI


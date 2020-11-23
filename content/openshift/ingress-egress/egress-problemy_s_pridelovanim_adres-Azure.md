---
title: "Egress v Azure OCP obecně "
date: 2020-11-04 
author: Tomas Dedic
description: "Egress rozbor moznosti a pouzit"
lead: ""
categories:
  - "Openshift"
  - "Azure"
tags:
  - "Networking"
  - "Egress"
---
## Definice egress adres

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
  V podstatě řeší to samé co jsem vydefinoval výše ale je to CRD.

+ EgressGateway nody (manuálni řešení)  
	**When a namespace has multiple egress IP addresses, if the node hosting the first egress IP address is unreachable, OpenShift Container Platform will automatically switch to using the next available egress IP address until the first egress IP address is reachable again.**
  Nadefinovat egress nody (minimálně dva) a přidělit jim egress adresy dle přidělených IP, každému namespacu pak přidělit dvě adresy.  Při této konfiguraci však přijdeme o půlku IP adres pro Egresy.

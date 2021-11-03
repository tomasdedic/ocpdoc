---
title: "Nifi Registry,OIDC [WOTW-11]"
date: 2021-10-03 
author: Tomas Dedic
description: "Desc"
lead: "workshop"
categories:
  - "wotw"
toc: true
autonumbering: true
---
**V dnešním dílu našeho oblíbeného seriálu se podíváme komplexnější deployment, vazbu na OIDC a HELM**  
**Takhle nějak by měl náš celkový deployment vypadat po usazení do AKS**  

{{< figure src="komunikacniflow.png" caption="takhle nejak by to melo vypadat" >}}


## NIFI REGISTRY
Budeme kontejnerizovat aplikaci nifi-registry [https://nifi.apache.org/registry.html](https://nifi.apache.org/registry.html), z pohledu businessu nemá vlastně žádnou funkcionalitu a je to jen podprojekt aplikace NIFI.  
Z našeho pohledu je to celkem zajímavé a to proto že poběží jako StatefullSet s vazbou na selfSigned CA a automatickým generováním klientských certifikátů.  
  
Pro deployment sem vytvořil [HELMCHART](https://github.com/tomasdedic/nifiregistry-WOTW.git).  
Obsahuje hlavní chart nifiregistry a subchart CA pro vazbu na certifikační autoritu a vytvoření certifikátů během bootstrapu.  
CA je selfigned tedy certifikáty jí vytvořené nejsou defaultně **"trusted"**.

```sh
#instalace prez helm s puvodnimi values
helm template nifi . --output-dir render --namespace nifi-registry -f values.yaml
helm install nifi .  --namespace nifi-registry -f values.yaml
```

**Aplikace podporuje jak klienstké certifikáty tak OIDC.**
Pro test klientského certifikátu který je automaticky vygenrovaný jako "CN=admin, OU=NIFI" a jsou mu v RBAC nifi-registry přidělena práva administrátora, viz helmchart>templates/statefullset.yaml  **lze nakopírovat tyto certifikáty lokálně a po importu do browseru a portforwardu na service endpoint se přihlásit**.

```sh
#copy certs
kb cp nifiregistry-0:/opt/nifi-registry/nifi-registry-current/certs/admin/key.pem key.pem
kb cp nifiregistry-0:/opt/nifi-registry/nifi-registry-current/certs/admin/crt.pem crt.pem
#udelat p12
openssl pkcs12 -export -out cert.p12 -in crt.pem -inkey key.pem
#port forward service port na localhost
kb port-forward service/nifiregistry 18443
#connect
firefox https://127.0.0.1:18443/nifi-registry
```

**Aplikace však neobsahuje a měl by ,nakonfigurovaný Ingress Route a vazbu na AAD OIDC pro autentizaci uživatelů.**  
Není tudíž možné se k ní připojit z internetu napřímo a autentizovat uživatele kterému jsme nedali certifikát.


## Igress
Pro ingress upravte helm chart tak aby obsahoval vazbu na váš ingressController, TLS certifikáty na objektu Ingresu vytořte přez CERT-MANAGER.  
Všechno jsme již probírali, případné howto je zde [AKS ingress,cert-manager](/openshift/aks/external_dns/external_dns/).  
**je potřeba si uvědomit že budeme navazovat spojení --->INGRESS (terminace TLS) ---->reencrypt selfigned CA certem kvuli trustu ---> nifiregistryENDPOINT**  
[INGRESS REENCRYPT to BACKEND](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/#backend-protocol)  
  
Upravte tedy HELMCHART tak aby renderoval ingress routu, která bude reencryptovat certifikátem CA.  

Certifikát pro CA je předgenerovaný a používá jméno **nifi-ca** jako DN, buď pro deployment přez HELM použijte toto jméno a nebo si ho přegenerujte
[CA generování](https://github.com/tomasdedic/nifiregistry-WOTW/blob/main/charts/ca/cacert/README.md)

## OAUTH2/OIDC
Povídání o [OAUTH2/OIDC](https://developer.okta.com/blog/2019/10/21/illustrated-guide-to-oauth-and-oidc) 
Česky je to popsané třeba zde [OIDC AAD](https://www.tomaskubica.cz/post/2019/moderni-autentizace-overovani-interniho-uzivatele-s-openid-connect-a-aad/).  
!!!CallBack ve vašem případě bude: **https://vas-ingress-host/nifi-api/access/oidc/callback**   
a konfigurace je opět zatažena do HELMCHARTU **jen je potřeba to nakonfigurovat na AAD a dát správné údaje.**
```sh
vim values.yaml
    oidc:
      enabled: true
      directoryId: d2480fab-7029-4378-9e54-3b7a474eb327
      discoveryUrl: https://login.microsoftonline.com/d2480fab-7029-4378-9e54-3b7a474eb327/v2.0/.well-known/openid-configuration
      clientId: 294d0e21-4f5a-4bdc-a6c1-4981f423b63a
      clientSecret: "superhusteheslo"
      claimIdentifyingUser: upn
      # fallbackClaimIndetifyingUser: upn
      ## Request additional scopes, for example profile
      additionalScopes: profile
```

## KROKY Miloše Frýby
- 1.  nakonfigurujete IngressControler v AKS
- 2.  nakonfigurujete CERT-MANAGER v AKS
- 3.  testněte generování certifikátů pro objekt typu ingress
- 4.  nastudujte OAUTH2/OIDC
- 5.  v Azure AAD vytvořte novou app registration a nakonfigurujete ji pro OIDC
- 6.  otestujte Ingress reencrypt směrovaný na NIFI service, tzn z venku se připojím na NIFI-registry 
- 7.  upravte helm chart tak aby generoval objekt typu Ingress 
- 8.  upravte helm chart vašimi údaji pro AAD OIDC a testněte přihlášení

DONE  
ADIOS COMPANEROS
{{< figure src="compag.jpg" caption="" >}}

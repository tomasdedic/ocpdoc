---
title: "Certbot DNS 01 and apply certs to OCP"
date: 2020-03-19 
author: Tomas Dedic
description: "How to create wildchar letsencrypt cert for domain"
lead: "ACME cert bot"
categories:
  - "Openshift"
tags:
  - "Config"
  - "SSL/TLS"
menu: side # Optional, add page to a menu. Options: main, side, footer
toc: true
 #sidebar: true
---
## Use certbot to generate certificate
A *Domain Name* consisting of a single asterisk character followed by a single full
stop character (\*.) followed by a Fully-Qualified Domain Name. For each **apps** subdomain we need to define cert. Not posible to use (\*.\*.\*.csas.elostech.cz)

```sh
sudo certbot -d "*.apps.poshi4.csas.elostech.cz"   --manual --preferred-challenges dns certonly
sudo certbot -d "*.apps.oshi43.csas.elostech.cz"   --manual --preferred-challenges dns certonly

  Please deploy a DNS TXT record under the name to your DNS
test:
dig _acme-challenge.apps.toshi44.csas.elostech.cz txt 
```
```sh
 #check certificate
openssl x509 -noout -text -in fullchain.pem
```
## Replacing default ingress certificate
+ You must have a wildcard certificate and its private key, both in the PEM format, for use.
+ The certificate must have a subjectAltName extension of *.apps.<clustername>.<domain>.

in case of using clusterwide proxy (not neccessary)
```sh
 #config map for CA
oc create configmap custom-ca \
     --from-file=ca-bundle.crt=ca.crt \
     -n openshift-config
 oc patch proxy/cluster \
     --type=merge \
     --patch='{"spec":{"trustedCA":{"name":"custom-ca"}}}'
```
all ingress routes:
```sh
oc create secret tls letsencrypt --cert=fullchain.pem --key privkey.pem -n openshift-ingress
 # or replace
oc create secret tls letsencrypt --cert=fullchain.pem --key privkey.pem -n openshift-ingress --dry-run -o yaml|oc replace -f -
oc patch ingresscontroller.operator default \
       --type=merge -p \
       '{"spec":{"defaultCertificate": {"name": "letsencrypt"}}}' \
       -n openshift-ingress-operator
 # or force recreate
for i in (oc get pods -n openshift-ingress -o name); oc delete -n openshift-ingress $i;end
```


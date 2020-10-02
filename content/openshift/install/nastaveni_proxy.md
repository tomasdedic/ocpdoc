---
title: "OCP Konfigurace proxy"
date: 2020-09-30 
author: Tomas Dedic
description: ""
lead: "Konfigurace proxy pro Openshift  "
categories:
  - "Openshift"
tags:
  - "Install"
---

## Konfigurace proxy pro instalaci OCP v izolovaném prostředí

```sh
povolené adresy na PROXY (whitelist) 
-------------------------------------
  .api.openshift.com #udates check                  
  cert-api.access.redhat.com #telemetry          
  api.access.redhat.com #telemetry               
  graph.windows.net #cloud credentials                
  cloud.redhat.com  #redhat insights                   

 adresy NOPROXY           
--------------------------
 management.azure.com     
 login.microsoftoline.com 
 .blob.core.windows.net  #blob storage 
 .csin.cz                 
 .csint.cz                
 .cs.cz                   
 .cst.cz                  
```
> The Proxy object’s status.noProxy field is populated by default with the instance metadata endpoint (169.254.169.254) and with the values of the networking.machineCIDR, networking.clusterNetwork.cidr, and networking.serviceNetwork fields from your installation configuration.
```sh
 adresy automaticky přidané admission-hook 
------------------------------------------
 .svc                                      
 10.128.0.0/14  #cluster network                           
 10.4.0.0/16    #machine network                           
 127.0.0.1                                 
 169.254.169.254 #Azure Instance Metadata service                           
 172.30.0.0/16   #service network                          
 api-int.[cluster-name].[cluster-domain]          
 etcd-*.[cluster-name].[cluster-domain]         
 localhost                                 
```
definice objektu proxy pro install-config.yaml
```yaml
 proxy:
   httpProxy: http://ngproxy-test.csint.cz:8080
   httpsProxy: http://ngproxy-test.csint.cz:8080
   noProxy: login.microsoftonline.com,management.azure.com,.blob.core.windows.net,.csint.cz
```
vytvořené CRD proxy
```sh
# install-config.yaml snippet
proxy:
  httpProxy: http://adresa:port
  httpsProxy: http://adresa:port
  noProxy: login.microsoftonline.com, management.azure.com, .blob.core.windows.net,.csin.cz,.csint.cz,.cs.cz,cst.cz
```



---
title: "OCP Konfigurace proxy"
date: 2020-09-30 
author: Tomas Dedic
description: "Desc"
lead: "Konfigurace proxy pro Openshift  "
categories:
  - "Openshift"
tags:
  - "Install"
---

|povolené adresy na PROXY (whitelist) |
|-------------------------------------|
|.api.openshift.com                   |
|cert-api.access.redhat.com           |
|api.access.redhat.com                |
|graph.windows.net                    |
|cloud.redhat.com                     |

|adresy NOPROXY             | 
|---------------------------|
|management.azure.com       |
|login.microsoftoline.com   |
|.blob.core.windows.net     |
|.csin.cz                   |
|.csint.cz                  |
|.cs.cz                     |
|.cst.cz                    |

> The Proxy object’s status.noProxy field is populated by default with the instance metadata endpoint (169.254.169.254) and with the values of the networking.machineCIDR, networking.clusterNetwork.cidr, and networking.serviceNetwork fields from your installation configuration.

```sh
# install-config.yaml snippet
proxy:
  httpProxy: http://adresa:port
  httpsProxy: http://adresa:port
  noProxy: login.microsoftonline.com, management.azure.com, .blob.core.windows.net, .csin.cz, .csint.cz, .cs.cz, cst.cz
```

vytvořené CDR na openshiftu pak vypadá jako
http://www.root.cz
"ahahaha"

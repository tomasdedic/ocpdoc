---
title: "AKS builtin policy"
date: 2021-03-18
author: Tomas Dedic
description: "short walkthrough"
lead: ""
categories:
  - "AKS"
tags:
  - "POLICY"
---
Je potřeba si zhodnotit zda chceme tyto politiky nasadit na všechny namespaces v AKS a nebo některé vynechat.  
Defaultně se vynechávají **kube-system a gatekeeper-system**.

## BUILTIN politiky

**Kubernetes cluster pod hostPath volumes should only use allowed host paths**  
  status: disabled   
  desc: kontejner si mǔže udělat mount pouze definovaných cest na nódu  

**Kubernetes cluster pods should only use allowed volume types**  
  status: **audit**  
  desc: pro mount půjdou použít jen konkrétní typy oddílů  
  parameters: [ "azureDisk", "azureFile", "configMap", "emptyDir", "hostPath", "persistentVolumeClaim", "secret" ]  

**Kubernetes clusters should be accessible only over HTTPS**  
  status: **deny**  
  desc:   ingress smí používat pouze HTTPS  

**Kubernetes clusters should not allow container privilege escalation**  
  status: **deny**  
  desc: v podstatě kontroluje zda proces může získat více oprávnění než proces rodičovský, z pohledu deploy kontroluje securityContext "allowPrivilegeEscalation: true" 
        AllowPrivilegeEscalation je vždy true pokud je container: 1) Privileged  2) má CAP_SYS_ADMIN  

**Kubernetes cluster services should listen only on allowed ports**  
  status: disabled  
  desc: omezení portů pro kubernetes services  

**Kubernetes clusters should use internal load balancers**  
  status: disabled  
  desc: omezení použití na jiný typ LB než internal v privateinstalaci nedává smysl  

**[Preview]: Kubernetes clusters should disable automounting API credentials**  
  status: disabled  
  desc: servisní účty se mountují automaticky tokeny do svých podů  

**Kubernetes cluster containers should only listen on allowed ports**  
  status: disabled  
  desc: omezení portů pro kontejnery  

**Kubernetes cluster pods should use specified labels**  
  status: disabled  
  desc: vynucení labelingu pro pody  

**Kubernetes cluster containers should not share host process ID or host IPC namespace**  
  status: **deny**  
  desc: izolace pod do svých namespaců tedy tak aby nemohli využívat host namespace (spec.hostPID: true) a také host namespace pro IPC (spec.hostIPC: true )  

**Kubernetes cluster containers should only use allowed AppArmor profiles**  
  status: disabled  
  desc: použití appArmor pro přístup kde zdrojům   
  pozn: zvážit pro další iteraci hardeningu  

**Kubernetes cluster containers should not use forbidden sysctl interfaces**  
  status: disabled  
  desc:  omezení sysctl interfacu pro kernel tunning z podhledu pod namespace ( kernel., net., dev. ...)  

**Kubernetes cluster pods should only use approved host network and port range**  
  status: disabled  
  desc: omezení použití host sítě, v podstatě omezení přístupu k síťovému namespacu nodu  

**Kubernetes cluster should not allow privileged containers**  
  status: **deny**  
  desc: containery nebudou moci běžet jako privileged   

**Kubernetes cluster containers should only use allowed seccomp profiles**  
  status: disabled  
  desc: použití seccomp pro přístup k systémovým voláním  
  pozn: zvážit pro další iteraci hardeningu  

**[Preview]: Kubernetes clusters should not use the default namespace**  
  status: disabled  
  desc: nebude default namespace po instalaci  

**[Preview]: Kubernetes clusters should not use specific security capabilities**  
  status: disabled  
  desc:  zakázat některé CAP [container.securityContext.capabilities](https://linux.die.net/man/7/capabilities)  

**Kubernetes cluster containers should only use allowed capabilities**  
  status: disabled  
  desc: definovat pouze vybrané [linux capabilities](https://linux.die.net/man/7/capabilities)  
  pozn: zvážit pro další iteraci hardeningu  

**[Preview]: Kubernetes clusters should not grant CAP_SYS_ADMIN security capabilities**  
  status: **deny**  
  desc: zbytečně silná cabability přidělá procesu, CAP_SYS_ADMIN ~=ROOT   

**Kubernetes cluster services should only use allowed external IPs**  
  status: disabled  
  desc: pokud bychom definovaly SVC třeba typu LB a ta si následně alokovala externalIP, mohli bychom omezit   

**Kubernetes cluster containers should run with a read only root file system**  
  status: disabled  
  desc: mountování root FS pro container jako readonly  

**Kubernetes cluster pods and containers should only use allowed SELinux options**  
  status: disabled  
  desc: definovat pouze vybrané SELinux options  
  pozn: zvážit pro další iteraci hardeningu  

**Kubernetes cluster containers CPU and memory resource limits should not exceed the specified limits**  
  status: disabled  
  desc: nastavit hard limits pro workload, vhodné pokud by uživetelé často nelimitovali svoje resourci a nutili by tak AKS třeba škálovat  

**Kubernetes cluster pods and containers should only run with approved user and group IDs**  
  status: disabled  
  desc: definovat GID a UID pod kterými mohou běžet, AKS nevyužívá mapping kdy uvnitř kontejneru se uživatel může jevit jinak než pro process na nodu (root uvnitř = proces běží pod rootem na nodu)  

**Kubernetes cluster pod FlexVolume volumes should only use allowed drivers**  
  status: disabled  
  desc: použití driverů pro PV, následně volané programově z nodu  

**Kubernetes cluster containers should only use allowed ProcMountType**  
  status: disabled  
  desc: v podstatě jde o to zda maskovat či nemaskovat /proc, standartně se použije DefaultProcMount který maskuje některé části v závislosti na container runtime  

**Kubernetes cluster containers should only use allowed images**  
  status: **deny**  
  desc: povolená bude pouze interní Artifactory  

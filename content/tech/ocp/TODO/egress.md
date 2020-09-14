---
title: "Egress question"
date: 2020-08-19 
author: Tomas Dedic
description: "Desc"
lead: "working"
categories:
  - "Openshift"
tags:
  - "OCP"
---
During Egress IP definition on Azure Cloud Provider, egress IP address are not propagate to underlying VMs. Address needs to be defined manually for each Azure VM as additional IP.
Our required configuration is supposed to have one Egress IP per namespace.

It seems we have basically two options:

+ [Egressip-ipam-operator](https://github.com/redhat-cop/egressip-ipam-operator)  
  Available only for AWS or Baremetal. 

+ define EgressGateway nodes  
  Define more egress gateway nodes(based on zones) and manually defined secondary IP adresses on node VMs. Each namespace will recieve more Egress IP (one IP per zone) and when a node hosting the first egress IP address is unreachable, OCP will automatically switch to using the next available egress IP address until the first egress IP address is reachable again.
  This approach works fine but suffers from IP address pool exhaustion and manual assigment need to be done on Azure.

Is there any other solution for Azure developed or planed by RedHat? 

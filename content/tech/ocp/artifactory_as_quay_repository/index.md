---
title: "Case usage of Artifactory as container proxy for Quay and public images"
date: 2020-03-02
author: Tomas Dedic
description: "Test install OCP cluster in private zone, without connection to internet and use replication and proxy for image repositories"
lead: ""
categories:
  - "Openshift"
tags:
  - "OCP"
  - "Artifactory"
  - "PrivateCluster"
---
# Purpose DISCLAMER 
For purposes of installing and use OCP in private zone with limited internet access, there is a need to use Artifactory as a source for public container images (QUAI, public containers). In this article we will solve such a problem a move on to installation of OCPv4 in such a environment.  
Artifactory will be installed to older OCP env and a new OCP will be made later with usage of "proxied" containers. 

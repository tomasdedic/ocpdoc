---
title: "Customizing ArgoCD for SOPS usage"
date:  2021-02-24
author: Tomas Dedic
description: "Nosná myšlenka automatický decrypting secretů přez Mozilla SOPS v workflow GITOPS tedy s využitím ArgoCD.  
              Pro storage klíčů použít Azure KV a přístup k němu řídit přez Managed Identitu zacílenou na deployment ArgoCD
              tedy použitím AAD pod identity."
lead: "Nasazeni SOPS pro GITOPS pouziti a auto decrypting prez Azure KV. Využití ManagedIdentity a AAD pod identity pro přístup k KV"
categories:
  - "Openshift"
tags:
  - "ARGOCD"
toc: true
autonumbering: true
thumbnail: "img/121367915_10157770255117399_360219505287172470_o.jpg"
---


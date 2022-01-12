---
title: "ArgoCD app deploy with clusterWide resources request"
date: 2021-11-22
author: Tomas Dedic
description: "Deploy an application with clusterWide resources into application/sys argo with only one GIT repo"
lead: "working"
categories:
  - "Openshift"
tags:
  - "ARGOCD"
toc: true
autonumbering: true
thumbnail: "img/argocwr.jpg"
---
## PRELUDE

Chceme dosáhnout toto aby aplikace která vyžaduje clusterWide resources (CRB,
SCC ...) byla stále deployovaná z jednoho repa.
Jen její část využívající tyto privileged resource by byla potvrzena z ARGOCD
SYS a část která je nevyžaduje byla z ARGOCD APP.

**Hlavní důvod je ten aby i skupina neprivilegovaných uživatelů měla přístup ke
své aplikaci a mohla například měnit její přímé zdroje, testovat úpravu helm
chartu a podobně.  Počítám s tím že CWR resource se nebudou měnit pravidelně ale
spíše v podobě "fire and forget".**

Jelikož to nebudou uplně business aplikace dropneme prozatím možnost použití
project operatoru/application operatoru a zdroje se vytvoří ručně.

Pokusim se využít ArgoCD kde pro AppArgo bude excludnut adresář z helmchartu
obsahující CWR, v systémovém Argu bude naopak pouze tento adresář a autosync
bude vyplý, tzn případná změna CRW resourců vyžaduje explicitní click v rámci
ARGOCD sys workflow, dá se říci že něco jako pull request.

```sh
#exclude directory
oc explain application.spec.source.directory --api-version argoproj.io/v1alpha1
```

## HELM chart

Celá aplikace je v jednom repository a pro potřeby ArgoCD renderována,
clusterWideResources jsou součástí template spolu s Argoapp definicemi a je
potřeba je nasadit s vyššími privilegii tedy přez ArgoSYS.

```sh
➤ helm template nifi helmcharts/ --output-dir argo_release --namespace csas-monolog-nifi \ 
  -f values-lab1-dex.yaml
# struktura z pohledu rootu vypada naslednovne  
➤ tree -L 2 .
.
├── argo_release
│   └── nifi
├── Chart.yaml
├── helmcharts
│   └── ...
└── values-lab1-dex.yaml
```

Application is defined in helmchart with **clusterWideResources subdir**, after
render app looks like this:

```sh
── templates
    ├── clusterWideResources
    │   ├── argoResources
    │   │   ├── argocd-application-controller-edit.yaml
    │   │   ├── argocd-server-view.yaml
    │   │   ├── csas-monolog-nifi-argoappProject.yaml
    │   │   ├── csas-monolog-nifi-argoapp.yaml
    │   │   ├── ocp_csas_monolog_nifi_ops-crbAdmin.yaml
    │   │   └── ocp_csas_monolog_nifi_ops-group.yaml
    │   ├── clusterrolebinding.yaml
    │   ├── clusterrole.yaml
    │   ├── csas-monolog-nifi-argoapp.yaml
    │   └── scc.yaml
    ├── configmap-rbac.yaml
    ├── configmap-utils.yaml
    ├── configmap.yaml
    ├── route.yaml
    ├── scc.yaml_bck
    ├── serviceaccount.yaml
    ├── service.yaml
    └── statefulset.yaml
```

## SYS ARGO

working in argocd sys repository
>> bootstrap a render  neumi v tento okamzik odkaz na systemovy zdroj v jinem
>> GITU, uplne se mi ten process nechce prepisovat a tak se smirim s tim pouzit
>> jako zdroj "plain" a tedy CRW objekty nahrat do dedikovaneho adresare uvnitr sys
>> ARGA

```sh
#copy rendered CWR files to ./resources/csas-monolg-nifi
#edit components file rerun render and push

#file ./values/components.yaml
CLUSTER_WIDE_RESOURCES_APP:
  - name: csas-monolog-nifi
    type: plain
    namespace: csas-monolog-nifi
    appconfig:
      spec:
        syncPolicy:
          syncOptions:
          - CreateNamespace=true
          automated:
            prune: false
            selfHeal: false

#rerun render 
./script/render_resources.sh

#file resources/bootstrap/csas-monolog-nifi.yaml se vytvoří
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: csas-monolog-nifi
  annotations:
    argocd.argoproj.io/sync-options: Prune=false
  namespace: csas-argocd-sys
spec:
  project: default
  destination:
    namespace: csas-monolog-nifi
    server: 'https://kubernetes.default.svc'
  source:
    repoURL: ssh://git@sdf.csin.cz:2222/ocp4/ocp-oaz-lab1-system.git
    targetRevision: 'master'
    path: resources/csas-monolog-nifi
    directory:
      recurse: true
  syncPolicy:
    automated:
      prune: false
      selfHeal: false
    syncOptions:
      - CreateNamespace=true

# push 
git push

```

Opomenu li CWR resourcy přímo pro aplikaci je potřeba provést konfiguraci AppArgoCD
tedy nadefinoavat **AppProject** CR a **Application** CR (zde použijeme exclude
trik na clusterWideResources subdir čímž můžeme zůstat v jednom repozitáři)

```yaml
---
# Source: nifi/templates/clusterWideResources/argoResources/argocd-application-controller-edit.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: argocd-application-controller-edit
  namespace: csas-monolog-nifi
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: edit
subjects:
- kind: ServiceAccount
  name: argocd-application-controller
  namespace: csas-argocd-app
---
# Source: nifi/templates/clusterWideResources/argoResources/argocd-server-view.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: argocd-server-view
  namespace: csas-monolog-nifi
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: view
subjects:
- kind: ServiceAccount
  name: argocd-server
  namespace: csas-argocd-app
---
# Source: nifi/templates/clusterWideResources/argoResources/csas-monolog-nifi-argoappProject.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  labels:
  name: csas-monolog-nifi
  namespace: csas-argocd-app
spec:
  clusterResourceBlacklist:
  - group: '*'
    kind: '*'
  description: nifi app deployment
  destinations:
  - namespace: csas-monolog-nifi
    server: https://kubernetes.default.svc
  namespaceResourceBlacklist:
  - group: 'argoproj.io'
    kind: AppProject
  - group: 'argoproj.io'
    kind: Application
  roles:
  - groups:
    - OCP_CSAS_MONOLOG_NIFI_DEV
    - OCP_CSAS_MONOLOG_NIFI_OPS
    name: edit
    policies:
    - p, proj:csas-monolog-nifi:edit, applications, get, csas-monolog-nifi/*,
      allow
    - p, proj:csas-monolog-nifi:edit, applications, sync, csas-monolog-nifi/*,
      allow
  - groups:
    - OCP_CSAS_MONOLOG_NIFI_USR
    name: view
    policies:
    - p, proj:csas-monolog-nifi:view, applications, get, csas-monolog-nifi/*,
      allow
  sourceRepos:
  - ssh://git@sdf.csin.cz:2222/ocp4/*.git
  - git@sdf.csin.cz:2222/ocp4/*.git
  - https://github.com/csas-ops/*.git
---
# Source: nifi/templates/clusterWideResources/argoResources/csas-monolog-nifi-argoapp.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: csas-monolog-nifi
  annotations:
    argocd.argoproj.io/sync-options: Prune=false
  namespace: csas-argocd-app
spec:
  project: csas-monolog-nifi
  destination:
    namespace: csas-monolog-nifi
    server: 'https://kubernetes.default.svc'
  source:
    repoURL: ssh://git@sdf.csin.cz:2222/ocp4/csas-monolog-nifi-lab1.git
    targetRevision: 'master'
    path: argo_release/nifi
    directory:
      exclude: '**/clusterWideResources/**'
      recurse: true
  syncPolicy:
    automated:
      prune: false
      selfHeal: false
    syncOptions:
      - CreateNamespace=true
---
# Source: nifi/templates/clusterWideResources/argoResources/ocp_csas_monolog_nifi_ops-crbAdmin.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ocp-csas-monolog-nifi-ops-admin
  namespace: csas-monolog-nifi
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: admin
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: OCP_CSAS_MONOLOG_NIFI_OPS
---
# Source: nifi/templates/clusterWideResources/argoResources/ocp_csas_monolog_nifi_ops-group.yaml
apiVersion: user.openshift.io/v1
kind: Group
metadata:
  name: OCP_CSAS_MONOLOG_NIFI_OPS
users:
  - tt-922@csast.cz
```

## APP ARGOCD

V aplikačním ArgoCD je vytvořena příslušná aplikace a je možné ji spravovat se
standartními právy pro AppArgoCD, přičemž CWR jsou umístěny v SysArgoCD

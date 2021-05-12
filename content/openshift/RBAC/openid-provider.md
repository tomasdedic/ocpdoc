---
title: OPENID AAD SANDBOX
date: 2020-10-06
author: Tomas Dedic
description: ""
lead: "napojení OCP na OPENID-> AAD, RBAC pro vytvořené uživatele, custom claims "
categories:
  - "OpenShift"
tags:
  - "RBAC"
  - "OAuth2/OIDC"
toc: true
autonumbering: true
---

# OPENID AAD provider
**OpenID Connect authorize proti AAD. Uživatel se autentizuje a je následně vytvořen v OCP.**  
Jakým způsobem je možné provést párování mezi unikáním identifikátorem pro AAD a OCP.  
Je možno v rámcí provisioningu dotáhnout "groupMembershipClaims" se seznamem skupin z AAD a jakým způsobem provést provisioning těchto skupin v rámci OCP.  

[podbrobnější popis jwt token inspekce](https://www.tomaskubica.cz/post/2019/moderni-autentizace-overovani-interniho-uzivatele-s-openid-connect-a-aad/)

## DEFINICE MS jwt openid scopes, claims 
[MS openid specification](https://login.microsoftonline.com/b8e7deb2-24d2-45cd-aaa5-b7648f6eba3d/v2.0/.well-known/openid-configuration)
```yaml
 # shortened 
  "scopes_supported": [
    "openid",
    "profile",
    "email",
    "offline_access"
  ],
  "claims_supported": [
    "sub",
    "iss",
    "cloud_instance_name",
    "cloud_instance_host_name",
    "cloud_graph_host_name",
    "msgraph_host",
    "aud",
    "exp",
    "iat",
    "auth_time",
    "acr",
    "nonce",
    "preferred_username",
    "name",
    "tid",
    "ver",
    "at_hash",
    "c_hash",
    "email"
  ]
```

## Openshift OpenID definition
```sh
oc get oauth cluster 
```

```yaml
identityProviders:
    - mappingMethod: claim
      name: AzureAD
      openID:
        claims:
          email:
            - email
          name:
            - name
          preferredUsername:
            - preferred_username
            - email
            - upn
        clientID: f43b7310-c604-446f-aff4-a1b11b876018
        clientSecret:
          name: azure-aad
        extraScopes:
          - email
          - profile
          - groups
          - name
          - upn
        issuer: 'https://login.microsoftonline.com/b8e7deb2-24d2-45cd-aaa5-b7648f6eba3d'
      type: OpenID
```
```yaml
# secret nadefinujeme jako

apiVersion: v1
data:
  # base64 client secret z Azure
  clientSecret: NmdfUmIuVzl3bTluaS1vb3hMclcuYXpNcDVYcTJnYUhkYwo=
kind: Secret
metadata:
  name: azure-aad
  namespace: openshift-config
type: Opaque
```
## OCP USERS and IDENTITIES
login over openshift console, login sucess, user provisioned 
```sh
oc get identities
oc get user 
```
```yaml
apiVersion: user.openshift.io/v1
fullName: Dědič Tomáš
identities:
- AzureAD:88C5K0N11gtnE1dQpiLUb49jNqKzlzJ9h8ZyzWB6gc0
kind: User
metadata:
  name: tdedic@trask.cz
  uid: 76ba718b-4b5e-4685-bb7f-59c2e3bff979
```
```yaml
apiVersion: user.openshift.io/v1
extra:
  email: tdedic@trask.cz
  name: Dědič Tomáš
  preferred_username: tdedic@trask.cz
kind: Identity
  name: AzureAD:88C5K0N11gtnE1dQpiLUb49jNqKzlzJ9h8ZyzWB6gc0
providerName: AzureAD
providerUserName: 88C5K0N11gtnE1dQpiLUb49jNqKzlzJ9h8ZyzWB6gc0
user:
  name: tdedic@trask.cz
  uid: 76ba718b-4b5e-4685-bb7f-59c2e3bff979
```

```sh
# list user in AAD and try to find some similar fields
az ad user list |jq -r '.[]|select(.userPrincipalName =="tdedic@trask.cz")'
```

## JWT token inspekce (obecné)
**Azure console --> app registration --->redirect uri --> http://localhost**
+ client_id
identifikátor naší aplikace
+ response_type
jakou odpověď očekáváme, pro začátek s implicitním flow tady dáme id_token
+ redirect_url
to bude kopírovat nastavení při registraci, tedy v našem případě http://localhost
+ response_mode
říkáme, jakým způsobem chceme token v redirectu doručit. Genericky vzato jsou tu varianty from_post (výsledek vypadá jako při odeslání HTML formuláře, tedy je to POST na nějaký endpoint), query (odpověď přijde jako běžné parametry GETu za otazníkem) nebo fragment (informace přijdou za symbolem #). U implicitního flow použijeme fragment.
+ scope
tady říkáme u OAuth2 k čemu chceme získat práva, v našem případě jde o právo na přihlášení=openid
+ state
nějaké náhodné číslo, které se nám vrátí i v odpovědi 
+ nonce
opět nějaké náhodné číslo, které AAD vloží přímo do id_tokenu (a podepíše) 

```sh
# localhost-token
https://login.microsoftonline.com/b8e7deb2-24d2-45cd-aaa5-b7648f6eba3d/oauth2/v2.0/authorize?client_id=5ecafeb2-5759-405b-9d73-2b28879e17a0&response_type=id_token&redirect_url=http%3A%2F%2Flocalhost&response_mode=fragment&scope=openid+profile+email+offline_access&state=12345&nonce=54321
```

vrátí se nám 403 a zkopírujeme string za http://localhost/#id_token=\
do [jwt.ms](https://jwt.ms)

token:
```yaml
{
  "typ": "JWT",
  "alg": "RS256",
  "kid": "BB8CeFVqyaGrGNuehJIiL4dfjzw"
}.{
  "aud": "c2d29042-792d-4b23-9bdf-9e341e465083",
  "iss": "https://login.microsoftonline.com/b8e7deb2-24d2-45cd-aaa5-b7648f6eba3d/v2.0",
  "iat": 1575980563,
  "nbf": 1575980563,
  "exp": 1575984463,
  "aio": "ATQAy/8NAAAAICL+OHHE/lPlSFx6/OS2mtEemb0yt0fjJ7dZzSL65XqhnKVgwZDTMCiI8oTXt16P",
  "groups": [
    "111980ba-31f2-499d-b021-6d90b684ba54"
  ],
  "name": "user-15",
  "nonce": "54321",
  "oid": "ac21b13a-84a3-4123-9ebf-70ef264c85d8",
  "preferred_username": "user-15@mspassporttrask.onmicrosoft.com",
  "sub": "CBrSMAstqP5tAWMIL6KcD0LzDKpdnMiJ5ws18sAkfeg",
  "tid": "b8e7deb2-24d2-45cd-aaa5-b7648f6eba3d",
  "uti": "i6PrMfxar0S6Tqre21L8AA",
  "ver": "2.0"
}
```

## Role a ClusterRole ve vazbě na vytvořené USER/IDENTITIES objekty
Autenticated user budou defaultně přiřazena virtuální skupiny:
```sh
system:authenticated  Automatically associated with all authenticated users.
system:authenticated:oauth  Automatically associated with all users authenticated with an OAuth access token.
system:unauthenticated Automatically associated with all unauthenticated users.
```
```sh
# clusterrole prirazene skupine system:authenticated, system:unauthenticated, system:authenticated:oauth
oc get clusterrolebindings -o json |jq -r \
'.items[]| select(.subjects[].name| contains("system:authenticated")) |{roleRef_kind: .roleRef.kind, roleRef_name:.roleRef.name,subject_kind:.subjects[].kind,subject_name:.subjects[].name}'
oc get clusterrolebindings -o json| jq -r '.items[]| select(.subjects[].name| contains("system:authenticated")) | .metadata.name'
```
**system:authenticated:oauth** má ale právo vytvářet projekty a to bych rád odstranil 
```sh
oc get clusterrolebindings -o json| jq -rj '.items[]| select(.subjects[].name| contains("system:authenticated")) | {clusterrole:.roleRef.name,clusterrolebinging:.metadata.name}'
oc get clusterrolebindings -o json| jq -r '.items[]| select(.subjects[].name| contains("system:authenticated")) | .roleRef.name'|xargs oc get clusterrole -o yaml



```yaml
 # pridam prava pro skupinu v tokenu

---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: clusteradmin
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: "111980ba-31f2-499d-b021-6d90b684ba54"
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
```

V JWT tokenu sice group mame ale v provisioningu do OCP se neprojeví a uživatel nemá práva přijatá z tokenu.\
Práva získá až po manuálním přiřazení do skupiny.
```yaml
apiVersion: user.openshift.io/v1
kind: Group
metadata:
  name: 111980ba-31f2-499d-b021-6d90b684ba54
users:
  - tdedic@mspassporttrask.onmicrosoft.com
```


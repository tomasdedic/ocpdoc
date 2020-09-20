---
title: OPENID AAD
date: 2019-12-09
author: Tomas Dedic
description: "OPENID AAD OPENSHIFT"
lead: "working"
toc: false # Optional, enable Table of Contents for specific post
categories:
  - "OpenShift"
tags:
  - "OCP"
  - "AAD"
  - "Azure"
menu: side # Optional, add page to a menu. Options: main, side, footer
sidebar: true
---

# OPENID AAD
**OpenID Connect authorize proti AAD. Uživatel se autorizuje a je následně vytvořen v OCP.**\
Jakým způsobem je možné provést párování mezi unikáním identifikátorem pro AAD a OCP.\
Je možno v rámcí provisioningu dotáhnout "groupMembershipClaims" se seznamem skupin z AAD a jakým způsobem provést provisioning těchto skupin v rámci OCP.\
Je pro OCP ve verzi >4.2 stále doporučené provádět LDAP sync nebo je nějaká řekněme více nativní metoda.\

[jwt token inspekce](https://www.tomaskubica.cz/post/2019/moderni-autentizace-overovani-interniho-uzivatele-s-openid-connect-a-aad/)

### OC VERSION
```sh
➤ oc version
Client Version: openshift-clients-4.3.0-201910250623-42-gc276ecb7
Server Version: 4.3.0-0.nightly-2019-11-02-092336
Kubernetes Version: v1.16.2
```

### DEFINICE openid 
[openid spec](https://login.microsoftonline.com/b8e7deb2-24d2-45cd-aaa5-b7648f6eba3d/v2.0/.well-known/openid-configuration)
```json
{
  "token_endpoint": "https://login.microsoftonline.com/b8e7deb2-24d2-45cd-aaa5-b7648f6eba3d/oauth2/v2.0/token",
  "token_endpoint_auth_methods_supported": [
    "client_secret_post",
    "private_key_jwt",
    "client_secret_basic"
  ],
  "jwks_uri": "https://login.microsoftonline.com/b8e7deb2-24d2-45cd-aaa5-b7648f6eba3d/discovery/v2.0/keys",
  "response_modes_supported": [
    "query",
    "fragment",
    "form_post"
  ],
  "subject_types_supported": [
    "pairwise"
  ],
  "id_token_signing_alg_values_supported": [
    "RS256"
  ],
  "response_types_supported": [
    "code",
    "id_token",
    "code id_token",
    "id_token token"
  ],
  "scopes_supported": [
    "openid",
    "profile",
    "email",
    "offline_access"
  ],
  "issuer": "https://login.microsoftonline.com/b8e7deb2-24d2-45cd-aaa5-b7648f6eba3d/v2.0",
  "request_uri_parameter_supported": false,
  "userinfo_endpoint": "https://graph.microsoft.com/oidc/userinfo",
  "authorization_endpoint": "https://login.microsoftonline.com/b8e7deb2-24d2-45cd-aaa5-b7648f6eba3d/oauth2/v2.0/authorize",
  "http_logout_supported": true,
  "frontchannel_logout_supported": true,
 "end_session_endpoint": "https://login.microsoftonline.com/b8e7deb2-24d2-45cd-aaa5-b7648f6eba3d/oauth2/v2.0/logout",
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
  ],
  "tenant_region_scope": "EU",
  "cloud_instance_name": "microsoftonline.com",
  "cloud_graph_host_name": "graph.windows.net",
  "msgraph_host": "graph.microsoft.com",
  "rbac_url": "https://pas.windows.net"
}
```
### APP ServicePrincipal definition manifest
```json
{
	"id": "39c1d462-2197-4259-90df-6c7a26141d44",
	"acceptMappedClaims": null,
	"accessTokenAcceptedVersion": null,
	"addIns": [],
	"allowPublicClient": null,
	"appId": "c2d29042-792d-4b23-9bdf-9e341e465083",
	"appRoles": [],
	"oauth2AllowUrlPathMatching": false,
	"createdDateTime": "2019-12-04T12:15:41Z",
	"groupMembershipClaims": "All",
	"identifierUris": [
		"https://oauth-openshift-console.apps.oshi4dev.csas.elostech.cz"
	],
	"informationalUrls": {
		"termsOfService": null,
		"support": null,
		"privacy": null,
		"marketing": null
	},
	"keyCredentials": [],
	"knownClientApplications": [],
	"logoUrl": null,
	"logoutUrl": null,
	"name": "csasoshi4devel",
	"oauth2AllowIdTokenImplicitFlow": true,
	"oauth2AllowImplicitFlow": false,
	"oauth2Permissions": [
		{
			"adminConsentDescription": "Allow the application to access csasoshi4devel on behalf of the signed-in user.",
			"adminConsentDisplayName": "Access csasoshi4devel",
			"id": "216275e4-9b30-4bee-99b3-0d41781cea38",
			"isEnabled": true,
			"lang": null,
			"origin": "Application",
			"type": "User",
			"userConsentDescription": "Allow the application to access csasoshi4devel on your behalf.",
			"userConsentDisplayName": "Access csasoshi4devel",
			"value": "user_impersonation"
		}
	],
	"oauth2RequirePostResponse": false,
	"optionalClaims": {
		"idToken": [],
		"accessToken": [
			{
				"name": "groups",
				"source": null,
				"essential": false,
				"additionalProperties": [
					"dns_domain_and_sam_account_name"
				]
			}
		],
		"saml2Token": [
			{
				"name": "groups",
				"source": null,
				"essential": false,
				"additionalProperties": [
					"dns_domain_and_sam_account_name"
				]
			}
		]
	},
	"orgRestrictions": [],
	"parentalControlSettings": {
		"countriesBlockedForMinors": [],
		"legalAgeGroupRule": "Allow"
	},
	"passwordCredentials": [
		{
			"customKeyIdentifier": "//5yAGIAYQBjAA==",
			"endDate": "2020-12-04T12:15:42.991764Z",
			"keyId": "b929dc22-7809-434f-a272-3baec2efbb76",
			"startDate": "2019-12-04T12:15:42.991764Z",
			"value": null,
			"createdOn": null,
			"hint": null,
			"displayName": null
		}
	],
	"preAuthorizedApplications": [],
	"publisherDomain": "mspassporttrask.onmicrosoft.com",
	"replyUrlsWithType": [
		{
			"url": "https://oauth-openshift.apps.oshi4dev.csas.elostech.cz/oauth2callback/OIDtest",
			"type": "Web"
		},
		{
			"url": "urn:ietf:wg:oauth:2.0:oob",
			"type": "InstalledClient"
		},
		{
			"url": "https://oauth-openshift.apps.oshi4dev.csas.elostech.cz/oauth2callback/AzureAD",
			"type": "Web"
		}
	],
	"requiredResourceAccess": [
		{
			"resourceAppId": "00000002-0000-0000-c000-000000000000",
			"resourceAccess": [
				{
					"id": "5778995a-e1bf-45b8-affa-663a9f3f4d04",
					"type": "Scope"
				},
				{
					"id": "6234d376-f627-4f0f-90e0-dff25c5211a3",
					"type": "Scope"
				},
				{
					"id": "311a71cc-e848-46a1-bdf8-97ff7156d8e6",
					"type": "Scope"
				},
				{
					"id": "c582532d-9d9e-43bd-a97c-2667a28ce295",
					"type": "Scope"
				},
				{
					"id": "cba73afc-7f69-4d86-8450-4978e04ecd1a",
					"type": "Scope"
				},
				{
					"id": "824c81eb-e3f8-4ee6-8f6d-de7f50d565b7",
					"type": "Role"
				},
				{
					"id": "5778995a-e1bf-45b8-affa-663a9f3f4d04",
					"type": "Role"
				}
			]
		},
		{
			"resourceAppId": "00000003-0000-0000-c000-000000000000",
			"resourceAccess": [
				{
					"id": "06da0dbc-49e2-44d2-8312-53f166ab848a",
					"type": "Scope"
				},
				{
					"id": "5f8c59db-677d-491f-a6b8-5f174b11ec1d",
					"type": "Scope"
				},
				{
					"id": "bc024368-1153-4739-b217-4326f2e966d0",
					"type": "Scope"
				},
				{
					"id": "e1fe6dd8-ba31-4d61-89e7-88639da4683d",
					"type": "Scope"
				},
				{
					"id": "7ab1d382-f21e-4acd-a863-ba3e13f7da61",
					"type": "Role"
				}
			]
		}
	],
	"samlMetadataUrl": null,
	"signInUrl": null,
	"signInAudience": "AzureADMyOrg",
	"tags": [],
	"tokenEncryptionKeyId": null
}
```

### provider definition
```yaml
---
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
spec:
  identityProviders:
  - name: AzureAD
    mappingMethod: claim
    type: OpenID
    openID:
      claims:
        preferredUsername:
        - upn
        - preferred_username
        email:
        - email
        name:
        - name
      clientID: c2d29042-792d-4b23-9bdf-9e341e465083
      clientSecret:
        name: aadidp-secret
      extraAuthorizeParameters:
        include_granted_scopes: "true"
      extraScopes:
      - email
      - profile
      - groups
      - name
      - upn
      issuer: https://login.microsoftonline.com/b8e7deb2-24d2-45cd-aaa5-b7648f6eba3d
```
### OC USERS
login over openshift console, login sucess, user provisioned 
```sh
➤ oc get user mole-12@mspassporttrask.onmicrosoft.com -o json
```
```json
{
    "apiVersion": "user.openshift.io/v1",
    "fullName": "Mole-12",
    "groups": null,
    "identities": [
        "AzureAD:zyBX-mCiVnA05CSohv2W2ZIPbmA7N8sKojx6IQlkP2g"
    ],
    "kind": "User",
    "metadata": {
        "creationTimestamp": "2019-12-06T10:08:38Z",
        "name": "mole-12@mspassporttrask.onmicrosoft.com",
        "resourceVersion": "14731567",
        "selfLink": "/apis/user.openshift.io/v1/users/mole-12%40mspassporttrask.onmicrosoft.com",
        "uid": "e1011ef5-cac1-4b0b-8c18-b5a6da366d5f"
    }
}
```
➤ oc get user mole-13@mspassporttrask.onmicrosoft.com -o json

```json
{
    "apiVersion": "user.openshift.io/v1",
    "fullName": "Mole-13",
    "groups": null,
    "identities": [
        "AzureAD:DBJV3Ey2GJ2T2nU-d71TeHmZnMeG5y1E8bCuJg_ZPb8"
    ],
    "kind": "User",
    "metadata": {
        "creationTimestamp": "2019-12-05T14:30:32Z",
        "name": "mole-13@mspassporttrask.onmicrosoft.com",
        "resourceVersion": "14295191",
        "selfLink": "/apis/user.openshift.io/v1/users/mole-13%40mspassporttrask.onmicrosoft.com",
        "uid": "dfea959e-70e9-4a9e-b014-84be18735829"
    }
}
```
### AAD user

```sh
➤ az ad user list |jq -r '.[]|select(.userPrincipalName =="mole-12@mspassporttrask.onmicrosoft.com")'
```
```json
{
  "accountEnabled": true,
  "ageGroup": null,
  "assignedLicenses": [],
  "assignedPlans": [],
  "city": null,
  "companyName": null,
  "consentProvidedForMinor": null,
  "country": null,
  "createdDateTime": "2019-12-04T19:21:54Z",
  "creationType": null,
  "deletionTimestamp": null,
  "department": null,
  "dirSyncEnabled": null,
  "displayName": "Mole-12",
  "employeeId": null,
  "facsimileTelephoneNumber": null,
  "givenName": null,
  "immutableId": null,
  "isCompromised": null,
  "jobTitle": null,
  "lastDirSyncTime": null,
  "legalAgeGroupClassification": null,
  "mail": null,
  "mailNickname": "mole-12",
  "mobile": null,
  "objectId": "c5f42a7d-7800-41b5-85a7-2440cc2dd65c",
  "objectType": "User",
  "odata.type": "Microsoft.DirectoryServices.User",
  "onPremisesDistinguishedName": null,
  "onPremisesSecurityIdentifier": null,
  "otherMails": [],
  "passwordPolicies": null,
  "passwordProfile": null,
  "physicalDeliveryOfficeName": null,
  "postalCode": null,
  "preferredLanguage": null,
  "provisionedPlans": [],
  "provisioningErrors": [],
  "proxyAddresses": [],
  "refreshTokensValidFromDateTime": "2019-12-04T19:21:54Z",
  "showInAddressList": null,
  "signInNames": [],
  "sipProxyAddress": null,
  "state": null,
  "streetAddress": null,
  "surname": null,
  "telephoneNumber": null,
  "thumbnailPhoto@odata.mediaEditLink": "directoryObjects/c5f42a7d-7800-41b5-85a7-2440cc2dd65c/Microsoft.DirectoryServices.User/thumbnailPhoto",
  "usageLocation": null,
  "userIdentities": [],
  "userPrincipalName": "mole-12@mspassporttrask.onmicrosoft.com",
  "userState": null,
  "userStateChangedOn": null,
  "userType": "Member"
}
```

### JWT token
obtain JWT token:
**Azure console --> app registration --->redirect uri --> http://localhost**
+ client_id
identifikátor naší aplikace, který vznikl při její registraci v AAD (označuje se tam jako Application ID)
+ response_type
jakou odpověď očekáváme, pro začátek s implicitním flow (doručení rovnou tokenu) tady dáme id_token
+ redirect_url
to bude kopírovat nastavení při registraci, tedy v našem případě http://localhost (v URL encode, protože znaky :// by prohlížeč zmátly)
+ response_mode
říkáme, jakým způsobem chceme token v redirectu doručit. Genericky vzato jsou tu varianty from_post (výsledek vypadá jako při odeslání HTML formuláře, tedy je to POST na nějaký endpoint), query (odpověď přijde jako běžné parametry GETu za otazníkem) nebo fragment (informace přijdou za symbolem #, což se dostane do browseru, ale ne dál - typické pro single-page aplikace). Ne všechny možnosti jsou z různých (primárně bezpečnostních) důvodů k dispozici u všech typů přihlášení/autorizace. U implicitního flow v dnešním článku použijeme fragment.
+ scope
tady říkáme u OAuth2 k čemu chceme získat práva, v našem případě jde o právo na přihlášení a dává se sem openid
+ state
nějaké náhodné číslo, které se nám vrátí i v odpovědi a my zkontrolujeme, že je stejné (brání před některými útoky)
+ nonce
opět nějaké náhodné číslo, které AAD vloží přímo do id_tokenu (a podepíše) a my si zkontrlujeme, že je stejné (bráníme se před replay útoky)

takže:

https://login.microsoftonline.com/b8e7deb2-24d2-45cd-aaa5-b7648f6eba3d/oauth2/v2.0/authorize?client_id=5ecafeb2-5759-405b-9d73-2b28879e17a0&response_type=id_token&redirect_url=http%3A%2F%2Flocalhost&response_mode=fragment&scope=openid+profile+email+offline_access&state=12345&nonce=54321

vrátí se nám 403 a zkopírujeme string za http://localhost/#id_token=\
do [jwt.ms](https://jwt.ms)

token:
```json
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
  "name": "Mole-15",
  "nonce": "54321",
  "oid": "ac21b13a-84a3-4123-9ebf-70ef264c85d8",
  "preferred_username": "mole-15@mspassporttrask.onmicrosoft.com",
  "sub": "CBrSMAstqP5tAWMIL6KcD0LzDKpdnMiJ5ws18sAkfeg",
  "tid": "b8e7deb2-24d2-45cd-aaa5-b7648f6eba3d",
  "uti": "i6PrMfxar0S6Tqre21L8AA",
  "ver": "2.0"
}
```

### Role a ClusterRole
```yaml

---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: clusteradmin
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: "111980ba-31f2-499d-b021-6d90b684ba54"
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: "70d80737-bb83-4971-9c6a-1fe23ba85be4"
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

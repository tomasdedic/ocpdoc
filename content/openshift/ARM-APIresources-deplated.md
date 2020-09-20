---
title: "ARM resource limits for OCP"
date: 2020-05-31 
author: Tomas Dedic
description: "Azure Arm resource limits customization"
lead: "OCP Config"
categories:
  - "Openshift"
  - "Azure"
tags:
  - "Config"
---
## ARM limitations

**For each Azure subscription and tenant, Resource Manager allows up to 12,000 read requests per hour and 1,200 write requests per hour, for certain resources it can be smaller.**
Jelikož se OCP neustále dotazuje Azure API je v přípaďe většího počtu clusterů v subskripci celkem časté přesáhnutí těchto limitů.

parametry pro volání API jsou následující:  


|**Name**                            | **Description**	                                                 | **Remark**|
|:----|:----:|-----:|
|cloudProviderBackoffRetries	    | Enable exponential backoff to manage resource retries	       | Boolean value, default to false|
|cloudProviderBackoffRetries	    | Backoff retry limit	                                         | Integer value, valid if cloudProviderBackoff is true|
|cloudProviderBackoffExponent	    | Backoff exponent	                                           | Float value, valid if cloudProviderBackoff is true|
|cloudProviderBackoffDuration	    | Backoff duration	                                           | Integer value, valid if cloudProviderBackoff is true|
|cloudProviderBackoffJitter	      | Backoff jitter	                                             | Float value, valid if cloudProviderBackoff is true|
|cloudProviderRateLimit	          | Enable rate limiting	                                       | Boolean value, default to false|
|cloudProviderRateLimitQPS	      | Rate limit QPS (Read)	                                       | Float value, valid if cloudProviderRateLimit is true|
|cloudProviderRateLimitBucket	    | Rate limit Bucket Size	                                     | Integar value, valid if cloudProviderRateLimit is true|
|cloudProviderRateLimitQPSWrite	  | Rate limit QPS (Write)	                                     | Float value, valid if cloudProviderRateLimit is true|
|cloudProviderRateLimitBucketWrite|	Rate limit Bucket Size	                                     | Integer value, valid if cloudProviderRateLimit is true|

**It might be better to change values to this, otherwise problems like 'cannot esure loadbalancer' will ocure. This problem is related in case more instances of Openshift Cluster is provisioned in one subscription.****
```sh
UseInstanceMetadata:          true,
CloudProviderBackoff:         true,			
CloudProviderBackoffRetries:  6,			
CloudProviderBackoffJitter:   1.0,			
CloudProviderBackoffDuration: 5,			
CloudProviderBackoffExponent: 1.5,			
CloudProviderRateLimit:       true,		
CloudProviderRateLimitQPS:    10.0,		
CloudProviderRateLimitBucket: 100,	
```
```sh
oc get cm cloud-provider-config -n openshift-config -o json|jq  -r '.data.config'|jq .
```
```yaml
# example ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: cloud-provider-config
  namespace: openshift-config
data:
  config: "{\n\t\"cloud\": \"AzurePublicCloud\",\n\t\"tenantId\": \"d2480fab-7029-4378-9e54-3b7a474eb327\",\n\t\"aadClientId\":
    \"\",\n\t\"aadClientSecret\": \"\",\n\t\"aadClientCertPath\": \"\",\n\t\"aadClientCertPassword\":
    \"\",\n\t\"useManagedIdentityExtension\": true,\n\t\"userAssignedIdentityID\":
    \"\",\n\t\"subscriptionId\": \"7504de90-f639-4328-a5b6-fde85e0a7fd9\",\n\t\"resourceGroup\":
    \"oshi43-f8vg4-rg\",\n\t\"location\": \"westeurope\",\n\t\"vnetName\": \"oshi_vnet\",\n\t\"vnetResourceGroup\":
    \"oshi_vnet_rg\",\n\t\"subnetName\": \"oshi-worker-subnet\",\n\t\"securityGroupName\":
    \"oshi43-f8vg4-node-nsg\",\n\t\"routeTableName\": \"oshi43-f8vg4-node-routetable\",\n\t\"primaryAvailabilitySetName\":
    \"\",\n\t\"vmType\": \"\",\n\t\"primaryScaleSetName\": \"\",\n\t\"cloudProviderBackoff\":
    true,\n\t\"cloudProviderBackoffRetries\": 6,\n\t\"cloudProviderBackoffExponent\":
    1.5,\n\t\"cloudProviderBackoffDuration\": 6,\n\t\"cloudProviderBackoffJitter\":
    1.0,\n\t\"cloudProviderRateLimit\": true,\n\t\"cloudProviderRateLimitQPS\": 10,\n\t\"cloudProviderRateLimitBucket\":
    100,\n\t\"cloudProviderRateLimitQPSWrite\": 6,\n\t\"cloudProviderRateLimitBucketWrite\":
    10,\n\t\"useInstanceMetadata\": true,\n\t\"loadBalancerSku\": \"standard\",\n\t\"excludeMasterFromStandardLB\":
    null,\n\t\"disableOutboundSNAT\": null,\n\t\"maximumLoadBalancerRuleCount\": 0\n}\n"
```

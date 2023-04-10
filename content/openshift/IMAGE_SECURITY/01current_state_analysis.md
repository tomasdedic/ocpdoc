## CURRENT STATE

### GLOSSARY
In the text I omit the options offered by AquaSecurity, the main reason is that I am a little unfamiliar with them and they mostly concern pipeline or runtime. Blocking containers in the runtime seems a bit unfortunate to me, but at the same time it can be functional, I don't want to judge.
  
At this time, there is no process to prevent an unwanted or lets say insecure container image from running on AKS. Any public registry can be used for "image pull" in AKS. Also, the security context in which the containers are run is not limited in any way and no security policies are applied to them. 
  

### Base Images applications are build on 
Na zaklade analyzy Dockerfiles z gitovych repozitaru projektu **doplit projekt** vychazi ze pro build aplikací je použito poměrně malé množství baseimages. Azure functions jsou navíc under hardening process to CIS level1 and security updates.
### Docker build best practices

#### Tagging builds


### All images running in AKS 
Except **kubernetes-sys** namespace








There are multiple solutions for security policies in Kubernetes, for us I have chosen two solutions to define security policies, either by using **Azure Policies** their implementation at the Kubernetes level is to use OpenPolicyAgent(Gatekeeper). Or use the Kubernetes build-in PodSecurityAdmission and the corresponding security standard. The two solutions overlap in their capabilities for the most part.  
Obe reseni jsou zalozeny na Admission webhooku tedy pri validaci API requestu pri volani kubernetes API.
## Azure Policies
[aks policy definitions](https://learn.microsoft.com/en-us/azure/aks/policy-reference) 

srovnani:
[azure policies](https://github.com/Azure/azure-policy/blob/master/built-in-policies/policySetDefinitions/Kubernetes/Kubernetes_PSPRestrictedStandard.json)   

[pod security admission restricted](https://kubernetes.io/docs/concepts/security/pod-security-standards/) 
## Pod Security Standards/Pod Security Admission

POZN:
kouknout zda jde v AKS nadefinovat vice runtimeClass
You can use Calico Network Policies, as they are supported with kubenet.




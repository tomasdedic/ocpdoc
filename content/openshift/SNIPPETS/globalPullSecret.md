### Global pull secret
Jak nadefinovat global pull secret 
```sh
oc get secret/pull-secret -n openshift-config -o json|jq -r '.data[".dockerconfigjson"]'|base64 -d
 # change global pull secret
oc set data secret/pull-secret -n openshift-config --from-file=.dockerconfigjson=<pull-secret-location> 
 # add new pull secret to secrets
 oc get secret -n openshift-config pull-secret -o json |jq -r '.data[]'|base64 -d|jq '.auths += {"artifactory.csas.elostech.cz":{"auth":"b2NwOlRyZTVaaXpxbEdKT1NZdzhCUVZ5ZGFXbjk0eVZNZg==","email":"dedtom@gmail.com"}}' >
```

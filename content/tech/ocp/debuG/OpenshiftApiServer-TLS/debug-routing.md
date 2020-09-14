```sh
oc scale --replicas 1 -n openshift-kube-apiserver-operator deployments/kube-apiserver-operator
oc scale --replicas 1 -n openshift-apiserver-operator deployments/openshift-apiserver-operator
oc delete -n openshift-kube-apiserver podnetworkconnectivitycheck --all
```

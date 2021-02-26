```sh
oc new-project group-sync-operator
helm repo add group-sync-operator https://redhat-cop.github.io/group-sync-operator
helm repo update
helm install group-sync-operator group-sync-operator/group-sync-operator
```
create App registration with 
- Group.Read.All
- GroupMember.Read.All
- User.Read.All
{{< figure src="img/Screenshot_2021-01-29_16-26-07.png" caption="App registration" >}}

{{< code file="azure-group-sync.yaml" lang="yaml" >}}
{{< code file="azure-groupsync.yaml" lang="yaml" >}}

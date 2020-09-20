## Elasticsearch
### Elasticsearch architecture

**Cluster**: Any non-trivial Elasticsearch deployment consists of multiple instances forming a cluster. Distributed consensus is used to keep track of master/replica relationships.  
**Node**: A single Elasticsearch instance.  
**Index**: A collection of documents. This is similar to a  database in the traditional terminology. 
Each data provider (like fluentd logs from a single Kubernetes cluster) should use a separate index to store and search logs. 
An index is stored across multiple nodes to make data highly available.  
**Shard**: Because Elasticsearch is a distributed search engine, an index is usually split into elements known as shards that are distributed across multiple nodes.(Elasticsearch automatically manages the arrangement of these shards. It also re-balances the shards as necessary, so users need not worry about these.)  
**Replica**: By default, Elasticsearch creates five primary shards and one replica for each index. This means that each index will consist of five primary shards, and each shard will have one copy.  

Deploy
**Client**: These nodes provide the API endpoint and can be used for queries. In a Kubernetes-based deployment these are deployed a service so that a logical dns endpoint can be used for queries regardless of number of client nodes.
**Master**: These nodes provide coordination. A single master is elected at a time by using distributed consensus. That node is responsible for deciding shard placement, reindexing and rebalancing operations.
**Data**: These nodes store the data and inverted index. Clients query Data nodes directly. The data is sharded and replicated so that a given number of data nodes can fail, without impacting availability.

#### Exposing Elasticsearch as a route
For testing purposes and API queries 
```yaml
 # elasticsearch-route.yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: elasticsearch
  namespace: openshift-logging
spec:
  host:
  to:
    kind: Service
    name: elasticsearch
  tls:
    termination: reencrypt
    destinationCACertificate: | 
```
```sh
oc extract secret/elasticsearch --to=. --keys=admin-ca
cat ./admin-ca | sed -e "s/^/      /" >> elasticsearch-route.yaml
set token (oc whoami -t) #get Bearer token
set routeES (oc get route -n openshift-logging elasticsearch -o json|jq -Mr '.spec.host')
 # operations index
curl -s -tlsv1.2 --insecure -H "Authorization: Bearer $token" "https://$routeES/.operations.*/_search?size=1" | jq
 # all indexes
curl -s -tlsv1.2 --insecure -H "Authorization: Bearer $token" "https://$routeES/_aliases" | jq
```


# OCP Logging in general 
**The cluster logging components are based upon Elasticsearch, Fluentd and Kibana.**

+ **logStore**: This is where the logs will be stored. The current implementation is **Elasticsearch**.
+ **collection**: This is the component that collects logs from the node, formats them, and stores them in the logStore. The current implementation is **Fluentd**.
+ **visualization**: This is the UI component used to view logs, graphs, charts, and so forth. The current implementation is **Kibana**.
+ **curation**: This is the component that trims logs by age. The current implementation is **Curator**.
+ **event routing**: This is the component forwards events to cluster logging. The current implementation is Event Router. The Event Router communicates with the OpenShift Container Platform and prints OpenShift Container Platform events to log of the pod where the event occurs.

The collector, Fluentd, is deployed to each node in the OpenShift Container Platform cluster. It collects all node and container logs and writes them to Elasticsearch (ES), Kibana to visualize.

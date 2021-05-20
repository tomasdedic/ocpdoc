## KAFKACAT

**Kafkacat is ideal solution for quick debug Eventhub/Kafka servers.**  
[ kafkacat git ]( https://github.com/edenhill/kafkacat )
### Deployment
```yaml
# quick deployment with nodeselector and toleration for choose a right node 
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: kafkacataff
  name: kafkacataff
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kafkacataff
  template:
    metadata:
      labels:
        app: kafkacataff
    spec:
      containers:
      # local redhat repository for monolog-nifi namespace
      - image: image-registry.openshift-image-registry.svc:5000/monolog-nifi/kafkacat:1.6.0
      #- image: edenhill/kafkacat:1.6.0
        name: kafkacataff
        resources: {}
        command: ["/bin/sh", "-c", "--"]
        args: ["while true; do sleep 30; done;"]
      nodeSelector:
        node-role.kubernetes.io/logging: ""
      tolerations:
      - key: "node-role"
        operator: "Equal"
        value: "logging"
        effect: "NoSchedule"
```
### USE AGAINTS EVENTHUB
Shared access signature SASL is used
```sh
# list all namespace in eventhub namespace
 kafkacat \
-b monolog.servicebus.windows.net:9093 \
-X security.protocol=sasl_ssl \
-X sasl.mechanism=PLAIN \
-X sasl.username='$ConnectionString' \
-X sasl.password='Endpoint=sb://monolog.servicebus.windows.net/;SharedAccessKeyName=ack;SharedAccessKey=$key' \
-L
```
```sh
# produce event with /etc/motd source
kafkacat \
-P \
-b monolog.servicebus.windows.net:9093 \
-t 'log.ocp.oaz_dev_argo_test_in' \
-X security.protocol=sasl_ssl \
-X sasl.mechanism=PLAIN \
-X sasl.username='$ConnectionString' \
-X sasl.password='Endpoint=sb://monolog.servicebus.windows.net/;SharedAccessKeyName=ack;SharedAccessKey=$key' \
-p 0 /etc/motd
```
```sh
# consume events from eventhub test
kafkacat \
-C \
-b monolog.servicebus.windows.net:9093 \
-t 'test' \
-X security.protocol=sasl_ssl \
-X sasl.mechanism=PLAIN \
-X sasl.username='$ConnectionString' \
-X sasl.password='Endpoint=sb://monolog.servicebus.windows.net/;SharedAccessKeyName=ack;SharedAccessKey=$key' 
```

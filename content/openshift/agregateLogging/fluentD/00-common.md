## Event structure and tags
Fluentd event consists of tag, time and record.
+ tag: Where an event comes from. For message routing
+ time: When an event happens. Nanosecond resolution
+ record: Actual log content. JSON object

```sh
The input plugin has responsibility for generating Fluentd event from data sources. For example, in_tail generates events from text lines. If you have following line in apache logs:
192.168.0.1 - - [28/Feb/2013:12:00:00 +0900] "GET / HTTP/1.1" 200 777
you got following event:
tag: apache.access         # set by configuration
time: 1362020400.000000000 # 28/Feb/2013:12:00:00 +0900
record: {"user":"-","method":"GET","code":200,"size":777,"host":"192.168.0.1","path":"/"}
```

## tags vs filestystem
```sh
#kubelet create a symlink to log
/var/log/containers/eventrouter-5dc5c565cd-dw7tj_openshift-logging_kube-eventrouter-ae666e925d23df257f2360c6bcadc1257a0913b2d98f377d9919085a71812bcf.log -> /var/log/pods/openshift-logging_eventrouter-5dc5c565cd-dw7tj_bf80aa43-5359-48fc-a4f1-9921569a4c43/kube-eventrouter/0.log
```
```sh
#struct
/var/log/containers/nameOfPod_nameOfNamespace_nameOfContainer-hash.log  
#corresponding tag
var.log.containers.nameOfPod_nameOfNamespace_nameOfContainer-hash.log

```

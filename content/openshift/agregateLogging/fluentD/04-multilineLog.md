## JAVA STACK multiline log
### Testing env
```yaml
apiVersion: apps/v1
kind: Deployment
namespace: logging-test
metadata:
  name: multiline-java
  labels:
    app: multiline-java
spec:
  replicas: 1
  selector:
    matchLabels:
      app: multiline-java
  template:
    metadata:
      labels:
        app: multiline-java
    spec:
      containers:
        - name: multiline-java
          image: image-registry.openshift-image-registry.svc:5000/blaster/multilinejavaloggenerator:v1
          # image: quay.io/dedtom/multilinejavaloggenerator:v1
          imagePullPolicy: IfNotPresent
```
### Definice problému
JAva stack Log  pokud je v plainu je multine
```sh
2021-06-07 13:18:15.176 ERROR 1 --- [   scheduling-1] o.s.s.s.TaskUtils$LoggingErrorHandler    : Unexpected error occurred in scheduled task
java.lang.RuntimeException: Error happened
        at com.fmja.FluentdMultilineJavaApplication.FluentdMultilineJavaApplication.logException(FluentdMultilineJavaApplication.java:37) ~[classes!/:0.0.1-SNAPSHOT]
        at jdk.internal.reflect.GeneratedMethodAccessor16.invoke(Unknown Source) ~[na:na]
        at java.base/jdk.internal.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43) ~[na:na]
        at java.base/java.lang.reflect.Method.invoke(Method.java:566) ~[na:na]
        at org.springframework.scheduling.support.ScheduledMethodRunnable.run(ScheduledMethodRunnable.java:84) ~[spring-context-5.3.3.jar!/:5.3.3]
        at org.springframework.scheduling.support.DelegatingErrorHandlingRunnable.run(DelegatingErrorHandlingRunnable.java:54) ~[spring-context-5.3.3.jar!/:5.3.3]
        at java.base/java.util.concurrent.Executors$RunnableAdapter.call(Executors.java:515) ~[na:na]
        at java.base/java.util.concurrent.FutureTask.runAndReset(FutureTask.java:305) ~[na:na]
        at java.base/java.util.concurrent.ScheduledThreadPoolExecutor$ScheduledFutureTask.run(ScheduledThreadPoolExecutor.java:305) ~[na:na]
        at java.base/java.util.concurrent.ThreadPoolExecutor.runWorker(ThreadPoolExecutor.java:1128) ~[na:na]
        at java.base/java.util.concurrent.ThreadPoolExecutor$Worker.run(ThreadPoolExecutor.java:628) ~[na:na]
        at java.base/java.lang.Thread.run(Thread.java:829) ~[na:na]
```
po pruchodu cri-o conmon je obohacen o metadata [store do logu  na nodu](/openshift/agregatelogging/log_snipets/#log-file-struct-on-fs) 

```sh
2021-06-08T09:24:38.563261747+00:00 stdout F 2021-06-08 09:24:38.562 ERROR 1 --- [   scheduling-1] o.s.s.s.TaskUtils$LoggingErrorHandler    : Unexpected error occurred in scheduled task
2021-06-08T09:24:38.563261747+00:00 stdout F
2021-06-08T09:24:38.563261747+00:00 stdout F java.lang.RuntimeException: Error happened
2021-06-08T09:24:38.563261747+00:00 stdout F    at com.fmja.FluentdMultilineJavaApplication.FluentdMultilineJavaApplication.logException(FluentdMultilineJavaApplication.java:37) ~[classes!/:0.0.1-SNAPSHOT]
2021-06-08T09:24:38.563261747+00:00 stdout F    at jdk.internal.reflect.GeneratedMethodAccessor16.invoke(Unknown Source) ~[na:na]
2021-06-08T09:24:38.563261747+00:00 stdout F    at java.base/jdk.internal.reflect.DelegatingMethodAccessorImpl.invoke(DelegatingMethodAccessorImpl.java:43) ~[na:na]
2021-06-08T09:24:38.563261747+00:00 stdout F    at java.base/java.lang.reflect.Method.invoke(Method.java:566) ~[na:na]
2021-06-08T09:24:38.563261747+00:00 stdout F    at org.springframework.scheduling.support.ScheduledMethodRunnable.run(ScheduledMethodRunnable.java:84) ~[spring-context-5.3.3.jar!/:5.3.3]
```
[kubelet-cri-logging](https://github.com/kubernetes/community/blob/master/contributors/design-proposals/node/kubelet-cri-logging.md)

fluentD to dále zpracuje line by line a nikdy nedojde ke spojení logů, v kibaně pak vypadají logy jako
{{< figure src="kibana-multiline.png" caption="kibana-multiline-javastack" >}}

### SOLUTION for FluentD 
Všechny eventy z source "/var/log/containers/**" tagovány jako "kubernetes.**" budou filtrovány na multiline regexp match (timestamp -2021-06-10 12:09:05.176) proti fieldu **log** a následně concatovány.  
Problém je s matchováním konce eventu pokud nepřijde další log, proto je nastaven flush_interval na 1
>The number of seconds after which the last received event log will be flushed. If specified 0, wait for next line forever.
Zároveň jak není schopen určit konec tak po překročení flushing intervalu přehodí zprávu do erroru, ale mi ten error vezmeme a přesměrujeme na standartní label.
  
  
```sh
    <label @JAVACONCAT>
      <filter kubernetes.**>
        @type concat
        key log
        multiline_start_regexp /^(\d{4}-\d{1,2}-\d{1,2} \d{1,2}:\d{1,2}:\d{1,2}.\d{0,3})/
        flush_interval 1
        timeout_label "@MEASURE"
      </filter>
      <match kubernetes.**>
        @type relabel
        @label @MEASURE
      </match>
    </label>
```
Problém tohoto řešení je ,že filtrujeme všechny logy z "/var/log/containers/**". **Uplně sem nedohlédnul na problémy které to může způsobovat ale fungujeme**.
{{< figure src="kibana-multiline-done.png" caption="kibana-multiline-done" >}}

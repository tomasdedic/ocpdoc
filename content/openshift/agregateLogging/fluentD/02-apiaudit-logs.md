## API AUDIT LOGS
Audit se týká **OpenShift API serveru, Kubernetes API serveru a the OAuth API serveru**.  

Enablujeme audit pro api servery
```sh
oc edit apiserver cluster

apiVersion: config.openshift.io/v1
  kind: APIServer
  metadata:
  ...
  spec:
    audit:
      profile: WriteRequestBodies 
# Default, WriteRequestBodies, or AllRequestBodies. The default profile is Default.
```


```bash
#fluent.conf
    <source>
      @type tail
      path "/var/log/kube-apiserver/*.log"
      pos_file "/var/log/kube-apiserver.log.pos"
      refresh_interval 5
      rotate_wait 5
      tag audit.*
      read_from_head "true"
      @label @MEASURE
      <parse>
        @type json
        <pattern>
          format json
          time_format '%Y-%m-%dT%H:%M:%S.%N%Z'
          keep_time_key true
        </pattern>
      </parse>
    </source>

    <source>
      @type tail
      path  "/var/log/openshift-apiserver/*.log"
      pos_file "/var/log/openshift-apiserver.log.pos"
      refresh_interval 5
      rotate_wait 5
      tag audit.*
      read_from_head "true"
      @label @MEASURE
      <parse>
        @type json
        <pattern>
          format json
          time_format '%Y-%m-%dT%H:%M:%S.%N%Z'
          keep_time_key true
        </pattern>
      </parse>
    </source>

    <source>
      @type tail
      path  "/var/log/oauth-apiserver/*.log"
      pos_file "/var/log/oauth-apiserver.log.pos"
      refresh_interval 5
      rotate_wait 5
      tag audit.*
      read_from_head "true"
      @label @MEASURE
      <parse>
        @type json
        <pattern>
          format json
          time_format '%Y-%m-%dT%H:%M:%S.%N%Z'
          keep_time_key true
        </pattern>
      </parse>
    </source>
```
final tags will be defined as:
```sh
audit.var.log.kube-apiserver.audit.log
audit.var.log.openshift-apierver.audit.log
audit.var.log/oauth-apiserver.audit.log
```
for tag filtering we will keep audit logs at verbs: **create,update,patch** for metadata and payload
```bash
      <filter audit.var.log.openshift-apiserver.** audit.var.log.kube-apiserver.**>
         @type grep
         <regexp>
           key verb
           pattern /create|update|patch/
         </regexp>
       </filter>
```
for oauth-apiserver we will preserve all audit logs


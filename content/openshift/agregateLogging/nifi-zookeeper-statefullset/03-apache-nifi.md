## Apache NIFI
Apache NIFI now runs as secured. It means all nodes ask CA for certificate during boot and Admin User and certificate
is created.  



### PERSISTENCE VOLUMES mapping
PV:  
  mountPath: /opt/nifi/data  
  mountPath: /opt/nifi/nifi-current/auth-conf/  
  mountPath: /opt/nifi/nifi-current/config-data  
  mountPath: /opt/nifi/flowfile_repository  
  mountPath: /opt/nifi/content_repository  
  mountPath: /opt/nifi/provenance_repository  
  mountPath: /opt/nifi/nifi-current/logs  
CM:  
  mountPath: /opt/nifi/nifi-current/conf/bootstrap.conf  
  mountPath: /opt/nifi/nifi-current/conf/nifi.temp -->nifi.properties  
  mountPath: /opt/nifi/nifi-current/conf/authorizers.temp -->authorizers.xml  
  mountPath: /opt/nifi/nifi-current/conf/authorizers.empty  
  mountPath: /opt/nifi/nifi-current/conf/bootstrap-notification-services.xml  
  mountPath: /opt/nifi/nifi-current/conf/login-identity-providers.xml  
  mountPath: /opt/nifi/nifi-current/conf/state-management.xml  
  mountPath: /opt/nifi/nifi-current/conf/zookeeper.properties  
  mountPath: /opt/nifi/data/flow.xml  
  mountPath: /opt/nifi/nifi-current/config-data/certs/generate_user.sh  

### AUTH
Nodes  and admin user are predefined(max replicaset 5):
```xml
/opt/nifi/nifi-current/conf/authorizers.xml

        {{- range $i := until $nodeidentities }}
        <property name="Node Identity {{ $i }}">CN={{ $fullname }}-{{ $i }}.{{ $fullname }}-headless.{{ $namespace }}.svc.cluster.local, OU=NIFI</property>
        {{- end }}
```
--> na zakladě tohoto souboru je upraven inicializační soubor s uživateli

```xml
/opt/nifi/nifi-current/auth-conf/users.xml

<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<tenants>
    <groups/>
    <users>
        <user identifier="171c708a-7250-37ba-95b7-e3d52258fc8a" identity="CN=nifi-3.nifi-headless.nifi.svc.cluster.local, OU=NIFI"/>
        <user identifier="47c717db-75da-3d54-8ab3-1731497291c7" identity="CN=admin, OU=NIFI"/>
        <user identifier="66afe269-10cc-37da-9785-3e72cbc609c8" identity="CN=nifi-2.nifi-headless.nifi.svc.cluster.local, OU=NIFI"/>
        <user identifier="5ac2302b-365e-3d9a-a24e-f17565d2ca08" identity="CN=nifi-0.nifi-headless.nifi.svc.cluster.local, OU=NIFI"/>
        <user identifier="f23a3051-d154-3f63-8674-fb8acb8a8030" identity="CN=nifi-4.nifi-headless.nifi.svc.cluster.local, OU=NIFI"/>
        <user identifier="802187fa-2f40-30b4-8554-c32b425ab945" identity="CN=nifi-1.nifi-headless.nifi.svc.cluster.local, OU=NIFI"/>
    </users>
</tenants>
```
Every identity with certificate signed by internal CA (CA pod) can access web UI (mutual TLS).
```sh
tls-toolkit.sh client \
  -c "nifi-ca" \
  -t domluveneheslokvulireplayattacku \
  --subjectAlternativeNames routehostname \
  -p 9090 \
  -D "CN=$USER, OU=NIFI" \
  -T PKCS12
```

Proto aby nebylo možné podepisovat si certifikáty z jiných namespaců je nasazena network policy omezující přístupy pouze na ingres(routu) nebo ze stejného namespacu.


In fact we struggle in validate internal CA, normaly we will use reencrypt at router with custom CA trust but:  
**passthrough - This is currently the only method that can support requiring client certificates, also known as two-way authentication.**  
It means that in browser our connection will be marked as "Not secure" because of use self-signed CA.

Directly in nifi users are presented like:
{{< figure src="img/nifi-users.png" caption="caption" >}}

RBAC model for users is presented 
```xml
/opt/nifi/nifi-current/auth-conf/authorizations.xml
```
For new user CSR is need to be done and approve it with custom CA, afterwards manually add user in NIFI-ui and define RBAC.
Node in lead will distribute xml files across all other nodes.  
Automatically generated certificates for node and Admin take place at **/opt/nifi/nifi-current/config-data/certs**  
For generating new user cert **generate_user.sh** script can be used. 

### ADMIN CERT
Admin CSR is generated automatically and signed during nifi bootstrap by CA.
```sh
# copy localy and import to browser
oc cp nifi-0:/opt/nifi/nifi-current/config-data/certs/admin/certAdmin.p12 ./certAdmin.p12
```

### GENERATE new USER
Helper script is ready for use in **nifi sts**, DN="CN=$user, OU=NIFI"
```sh
oc rsh nifi-0
# create certificate 
/opt/nifi/nifi-current/config-data/certs/generate_user.sh  $user
# cert is created in 
/opt/nifi/nifi-current/config-data/certs/$user/cert_$user.p12
```
```sh
# copy cert to local and import it to browser
oc cp nifi-0:/opt/nifi/nifi-current/config-data/certs/$user/cert_$user.p12 ./cert_${user}.p12
```

### SCALING
Škálovat můžeme až do hodnoty 5, kvůli předefinovaným identitám. Problém je se škálováním směrem dolů. Odpojený nifi nód zůstane ve stavu disconnected a je nutné ho ručně smazat(konfiguračně je cluster přepnut do readonly).  

*In a NiFi cluster, NiFi wants to make sure consistency across all nodes. You can't have each node in a NiFi cluster running a different version/state of the flow.xml.gz file. In a cluster, NiFi will replicate a request (such as stop x processor(s)) to all nodes. Since a node is not connected, that replication cannot occur. So to protect the integrity of the cluster, the NiFi canvas is essentially read-only while a node is disconnected.*

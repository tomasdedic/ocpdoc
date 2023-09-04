## 94. Integrace na centralni trustStore
Potřebné CA certifikáty ve formátu PEM, JKS a jejich provisioning směrem k workloadu.

### 1. custom CA trust (X509)
certifikáty pro CA trust vloženy do CM
```yaml
apiVersion: v1
data:
  ca-bundle.crt: |
    # CAIR3 CSAS
    -----BEGIN CERTIFICATE-----
    -----END CERTIFICATE-----

    #CAIMS2
    -----BEGIN CERTIFICATE-----
    -----END CERTIFICATE-----

    #CAIMST2
    -----BEGIN CERTIFICATE-----
    -----END CERTIFICATE-----

    #CAIRT3
    -----BEGIN CERTIFICATE-----
    -----END CERTIFICATE-----
kind: ConfigMap
metadata:
  name: user-ca-bundle
  namespace: openshift-config
```

Injekce certifikátu do ConfigMapy:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: trusted-ca
  namespace: appnamespace
  labels:
    config.openshift.io/inject-trusted-cabundle: "true"
```
**Takto labelovaná configmapa bude obsahovat jak náš custom trust tak i obecný RH CA trust**

Reference v aplikaci:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-example-custom-ca-deployment
  namespace: my-example-custom-ca-ns
spec:
  ...
    spec:
      containers:
        - name: my-container-that-needs-custom-ca
          volumeMounts:
          - name: trusted-ca
            mountPath: /etc/pki/ca-trust/extracted/pem
            readOnly: true
      volumes:
      - name: trusted-ca
        configMap:
          name: trusted-ca
          items:
            - key: ca-bundle.crt
              path: tls-ca-bundle.pem
```
### 2. JKS trust
Pro vytvoření JKS trustu z CA trust bundlu využijeme funkcionalitu **cert-utils-operatoru** který přez interní keystore vytvoří JKS trust z CA trust bundlu a injektne zpátky do configmapy.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: trusted-ca
  namespace: appnamespace
  labels:
    config.openshift.io/inject-trusted-cabundle: "true"
  annotations:
    cert-utils-operator.redhat-cop.io/generate-java-truststore: "true"
```

Configmapa pak vypadá:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: trusted-ca
  namespace: appnamespace
  labels:
    config.openshift.io/inject-trusted-cabundle: "true"
  annotations:
    cert-utils-operator.redhat-cop.io/generate-java-truststore: "true"
binaryData:
  truststore.jks: ...
data:
  ca-bundle.crt: ...

```

Reference v aplikaci pak může vypadat jako:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-example-custom-ca-deployment
  namespace: my-example-custom-ca-ns
spec:
  ...
    spec:
      containers:
        - name: my-container-that-needs-custom-ca
          volumeMounts:
          - name: trusted-ca
            mountPath: /etc/pki/ca-trust/extracted/pem
            readOnly: true
          - mountPath: /etc/pki/ca-trust/extracted/java
            name: jks-trust
            readOnly: true
      volumes:
      - name: trusted-ca
        configMap:
          name: trusted-ca
          items:
            - key: ca-bundle.crt
              path: tls-ca-bundle.pem
      - name: jks-trust
        configMap:
          name: trusted-ca
          items:
            - key: truststore.jks
              path: cacerts
```
Defaultní heslo pro keystore je **changeit**. Dá se změnit přez anotaci konfigmapy
```yaml
annotation:
  cert-utils-operator.redhat-cop.io/java-keystore-password: heslo
```
Alias pro certifikáty v keystoru je **alias**.



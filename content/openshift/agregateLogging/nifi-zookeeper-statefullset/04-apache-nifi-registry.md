## APACHE NIFI registry STS
+ Implementation of a Flow Registry for storing and managing versioned flows
+ Integration with NiFi to allow storing, retrieving, and upgrading versioned flows from a Flow Registry
  
Simple sts running with replicaset 1.
### TLS CERTIFICATES for user access
Certificates will be generated with  tls-toolkit against running CA
```yaml
        - name: cert-request
          imagePullPolicy: "IfNotPresent"
          image: "apache/nifi-toolkit:1.13.2"
          command:
            - bash
            - -c
            - |
              CERT_PATH="/opt/nifi-registry/nifi-registry-current/certs"
              CA_ADDRESS="nifi-ca:9090"
              until echo "" | timeout -t 2 openssl s_client -connect "${CA_ADDRESS}"; do
                # Checking if ca server using nifi-toolkit is up
                echo "Waiting for CA to be available at ${CA_ADDRESS}"
                sleep 2
              done;
              # generate node cert function
              generate_node_cert() {
               ${NIFI_TOOLKIT_HOME}/bin/tls-toolkit.sh client \
                -c "nifi-ca" \
                -t sixteenCharacters \
                --subjectAlternativeNames nifi-registry.apps.oshi43.sudlice.org, $(hostname -f) \
                -D "CN=$(hostname -f), OU=NIFI" \
                -p 9090
                }
              cd ${CERT_PATH}
              #certs generating (reuse old certs if available)
              # 1. nifi-registry node cert
              if [ ! -f config.json ] || [ ! -f keystore.jks ] || [ ! -f truststore.jks ];then 
                rm -f *
                generate_node_cert
              fi
          volumeMounts:
            - name: "databaseflow-storage"
              mountPath: /opt/nifi-registry/nifi-registry-current/certs
              subPath: nifi-registry-current/certs
```
node cert will be used later when running registry
```yaml
              export_tls_values() {
                CERT_PATH=/opt/nifi-registry/nifi-registry-current/certs
                export AUTH=tls
                export KEYSTORE_PATH=${CERT_PATH}/keystore.jks
                export KEYSTORE_TYPE=jks
                export KEYSTORE_PASSWORD=$(jq -r .keyStorePassword ${CERT_PATH}/config.json)
                export KEY_PASSWORD=$KEYSTORE_PASSWORD
                export TRUSTSTORE_PATH=${CERT_PATH}/truststore.jks
                export TRUSTSTORE_TYPE=jks
                export TRUSTSTORE_PASSWORD=$(jq -r .trustStorePassword ${CERT_PATH}/config.json)
                export NIFI_REGISTRY_WEB_HTTPS_HOST=$(hostname -f)
                export INITIAL_ADMIN_IDENTITY="CN=admin, OU=NIFI"
              }
              export_tls_values
                ${NIFI_REGISTRY_BASE_DIR}/scripts/start.sh
```
Admin certificate generated during NIFI bootstrap can be used.
```xml
<!-- flow.xml tweaking -->
        <flowRegistry>
            <id>{{ default uuidv4 }}</id>
            <name>default</name>
            <url>{{ template "registry.url" . }}</url>
            <description/>
        </flowRegistry>
```
flow.xml file need to be updated to reflex TLS

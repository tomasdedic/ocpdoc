## CIS benchmarks flow
### SCANS settings
```sh
➤ oc get scansettings
NAME                 AGE
default              4d20h
default-auto-apply   4d20h
```
Only difference between scan settings is that auto-apply will apply remediation tasks automatically.  
Scan runs by default every day at 1 in the morning.It’ll also allocate 1Gi to store our raw results.  
```sh
➤ yq d <(oc describe scansettings default-auto-apply) Metadata
Name: default-auto-apply
Namespace: openshift-compliance
Labels: <none>
Annotations: <none>
API Version: compliance.openshift.io/v1alpha1
Auto Apply Remediations: true
Auto Update Remediations: true
Kind: ScanSetting
Raw Result Storage:
  Pv Access Modes: ReadWriteOnce
  Rotation: 3
  Size: 1Gi
Roles: worker master
Scan Tolerations:
  Effect: NoSchedule
  Key: node-role.kubernetes.io/master
  Operator: Exists
Schedule: 0 1 * * *
Events: <none>
```
### RUNNING SCANS
We need to join predefined profiles(rules sets) with SCAN. In first iteration we would like to use **CIS profiles** with **default scansetting**.  
Lets create the scan binding.

```yaml
---
apiVersion: compliance.openshift.io/v1alpha1
kind: ScanSettingBinding
metadata:
  name: cis
profiles:
- apiGroup: compliance.openshift.io/v1alpha1
  kind: Profile
  name: ocp4-cis
- apiGroup: compliance.openshift.io/v1alpha1
  kind: Profile
  name: ocp4-cis-node
settingsRef:
  apiGroup: compliance.openshift.io/v1alpha1
  kind: ScanSetting
  name: default
```
The above manifest created a **ComplianceSuite** object with the same name as the **ScanSettingBinding**, which contains a lot of valuable information and helps us track our scans.
The **ComplianceSuite** itself generates low-level objects called **ComplianceScans** which have different scopes of execution but ensure the right parameters are used during the scan.

Ok now wait for the scan to finish
```sh
➤ oc wait --timeout 120s --for condition=ready compliancesuite cis
#then
➤ oc get compliancescans

NAME                   PHASE   RESULT
ocp4-cis               DONE    NON-COMPLIANT
ocp4-cis-node-master   DONE    NON-COMPLIANT
ocp4-cis-node-worker   DONE    NON-COMPLIANT
```
And to see rule by rule
```sh
➤ oc get compliancecheckresults
#get failed checks
➤ oc get compliancecheckresults -l compliance.openshift.io/check-status=FAIL --no-headers
```
Some tasks have automatic remediation
```sh
➤ oc get complianceremediations
```
```sh
# to rescan
➤ oc annotate compliancescan ocp4-cis "compliance.openshift.io/rescan="
```


### SCAN RESULTS PERSISTENCE
Due to default scan settings results are persisted, to view created PVC:
TODO: need to change PV to some other StorageClass
```sh
➤ oc get compliancesuites cis -o jsonpath='{range .status.scanStatuses[*].resultsStorage}{.name}{"\t"}{.namespace}{"\n"}'
```
OK tak ted bude potreba zkonvertovat reporty do html a vypropagovat na nginx na endpoint, pred to postavit oauth proxy




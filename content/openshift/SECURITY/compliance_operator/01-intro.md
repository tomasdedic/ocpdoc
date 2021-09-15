We would like to use ComplianceOperator as automatic scanning device, whether our cluster are "complient" at least with CIS Benchmark.  
As best option seems to be to use ComplianceOperator "as is" and don't write custom policies and aim to remediation tasks instead, to  
build a automatic compliance.  
It would be nice to integrate CO with some console to visualise results automatically for each cluster. AFAIK CO is able to generate html report
for each scan and save it to PV inside the OCP cluster.  
Later work is to enable this report on some Endpoint and enable access for authorized OCP users (oauth proxy).

## COMPLIANCE CRDs
```sh
#folowing CRD are added to API
➤ oc api-resources|awk 'NR==1||/compliance/'
NAME                                  SHORTNAMES                         APIVERSION                                    NAMESPACED   KIND
compliancecheckresults                ccr,checkresults,checkresult       compliance.openshift.io/v1alpha1              true         ComplianceCheckResult
complianceremediations                cr,remediations,remediation,rems   compliance.openshift.io/v1alpha1              true         ComplianceRemediation
compliancescans                       scans,scan                         compliance.openshift.io/v1alpha1              true         ComplianceScan
compliancesuites                      suites,suite                       compliance.openshift.io/v1alpha1              true         ComplianceSuite
profilebundles                        pb                                 compliance.openshift.io/v1alpha1              true         ProfileBundle
profiles                              profs,prof                         compliance.openshift.io/v1alpha1              true         Profile
rules                                                                    compliance.openshift.io/v1alpha1              true         Rule
scansettingbindings                   ssb                                compliance.openshift.io/v1alpha1              true         ScanSettingBinding
scansettings                          ss                                 compliance.openshift.io/v1alpha1              true         ScanSetting
tailoredprofiles                      tp,tprof                           compliance.openshift.io/v1alpha1              true         TailoredProfile
variables                             var                                compliance.openshift.io/v1alpha1              true         Variable
```

## PREDEFINED PROFILES
**Compliance operator comes bundled with predefined profiles**. In following parts we will aim on **CIS profiles**

```sh
➤ oc get profile.compliance -o name
NAME                 
ocp4-cis             
ocp4-cis-node        
ocp4-e8              
ocp4-moderate        
ocp4-moderate-node   
rhcos4-e8            
rhcos4-moderate      
```

```txt
➤ oc get profile.compliance -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.title}{"\n"}{.description}{"\n"}{end}'

>> ocp4-cis                CIS Red Hat OpenShift Container Platform 4 Benchmark
This profile defines a baseline that aligns to the Center for Internet Security® Red Hat OpenShift Container Platform 4 Benchmark™, V0.3, currently unreleased.
This profile includes Center for Internet Security® Red Hat OpenShift Container Platform 4 CIS Benchmarks™ content. 
Note that this part of the profile is meant to run on the Platform that Red Hat OpenShift Container Platform 4 runs on top of. 
This profile is applicable to OpenShift versions 4.6 and greater.

>> ocp4-cis-node           CIS Red Hat OpenShift Container Platform 4 Benchmark
This profile defines a baseline that aligns to the Center for Internet Security® Red Hat OpenShift Container Platform 4 Benchmark™, V0.3, currently unreleased. 
This profile includes Center for Internet Security® Red Hat OpenShift Container Platform 4 CIS Benchmarks™ content.
Note that this part of the profile is meant to run on the Operating System that Red Hat OpenShift Container Platform 4 runs on top of.
This profile is applicable to OpenShift versions 4.6 and greater.

>> ocp4-e8                 Australian Cyber Security Centre (ACSC) Essential Eight
This profile contains configuration checks for Red Hat OpenShift Container Platform that align to the Australian Cyber Security Centre (ACSC) Essential Eight. 
A copy of the Essential Eight in Linux Environments guide can be found at the ACSC website: https://www.cyber.gov.au/acsc/view-all-content/publications/hardening-linux-workstations-and-servers

>> ocp4-moderate           NIST 800-53 Moderate-Impact Baseline for Red Hat OpenShift - Platform level
This compliance profile reflects the core set of Moderate-Impact Baseline configuration settings for deployment of Red Hat OpenShift Container Platform into U.S. Defense, Intelligence, and Civilian agencies. 
Development partners and sponsors include the U.S. National Institute of Standards and Technology (NIST), U.S. Department of Defense, the National Security Agency, and Red Hat. 
This baseline implements configuration requirements from the following sources: - NIST 800-53 control selections for Moderate-Impact systems (NIST 800-53)
For any differing configuration requirements, e.g. password lengths, the stricter security setting was chosen. 
Security Requirement Traceability Guides (RTMs) and sample System Security Configuration Guides are provided via the scap-security-guide-docs package. 
This profile reflects U.S. Government consensus content and is developed through the ComplianceAsCode initiative, championed by the National Security Agency. 
Except for differences in formatting to accommodate publishing processes, this profile mirrors ComplianceAsCode content as minor divergences, such as bugfixes, work through the consensus and release processes.

>> ocp4-moderate-node      NIST 800-53 Moderate-Impact Baseline for Red Hat OpenShift - Node level
This compliance profile reflects the core set of Moderate-Impact Baseline configuration settings for deployment of Red Hat OpenShift Container Platform into U.S. Defense, Intelligence, and Civilian agencies. 
Development partners and sponsors include the U.S. National Institute of Standards and Technology (NIST), U.S. Department of Defense, the National Security Agency, and Red Hat. 
This baseline implements configuration requirements from the following sources: - NIST 800-53 control selections for Moderate-Impact systems (NIST 800-53) For any differing configuration requirements, e.g. password lengths, the stricter security setting was chosen. 
Security Requirement Traceability Guides (RTMs) and sample System Security Configuration Guides are provided via the scap-security-guide-docs package. 
This profile reflects U.S. Government consensus content and is developed through the ComplianceAsCode initiative, championed by the National Security Agency. 
Except for differences in formatting to accommodate publishing processes, this profile mirrors ComplianceAsCode content as minor divergences, such as bugfixes, work through the consensus and release processes.

>> rhcos4-e8                 Australian Cyber Security Centre (ACSC) Essential Eight
This profile contains configuration checks for Red Hat Enterprise Linux CoreOS that align to the Australian Cyber Security Centre (ACSC) Essential Eight. 
A copy of the Essential Eight in Linux Environments guide can be found at the ACSC website: https://www.cyber.gov.au/acsc/view-all-content/publications/hardening-linux-workstations-and-servers

>> rhcos4-moderate           NIST 800-53 Moderate-Impact Baseline for Red Hat Enterprise Linux CoreOS
This compliance profile reflects the core set of Moderate-Impact Baseline configuration settings for deployment of Red Hat Enterprise Linux CoreOS into U.S. Defense, Intelligence, and Civilian agencies. 
Development partners and sponsors include the U.S. National Institute of Standards and Technology (NIST), U.S. Department of Defense, the National Security Agency, and Red Hat. 
This baseline implements configuration requirements from the following sources: - NIST 800-53 control selections for Moderate-Impact systems (NIST 800-53) For any differing configuration requirements, e.g. password lengths, the stricter security setting was chosen. 
Security Requirement Traceability Guides (RTMs) and sample System Security Configuration Guides are provided via the scap-security-guide-docs package. 
This profile reflects U.S. Government consensus content and is developed through the ComplianceAsCode initiative, championed by the National Security Agency. 
Except for differences in formatting to accommodate publishing processes, this profile mirrors ComplianceAsCode content as minor divergences, such as bugfixes, work through the consensus and release processes.
```

## NIFI,CA,REGISTRY
### PERSISTENCE
Volumů v helmchartech je zbytečně moc, pro každý deployment/sts to zmáčkneme na jeden PV přez **subPath** a skusim použít NFS které je zatím v preview
a nemá dynamického provisionera ale PV/NFS shary si nadefinujeme ručně.  
[NFS definice](/openshift/persistence/nfsazurefile-k8s/)

### Autentizace-Autorizace


## NIFI CA

- Uzivatele se “vyklikavaji” ve webu NiFi. Toolkit generuje “pouze” certifikat pro overeni ve webovem GUI.
- muzeme toolkit pouzit pro vygenerovani inicialni secure konfigurace, ktera se pouzije do nifi.properties (nastaveni https, keystore+truststore) – nicmene, vubec nevim, zdali je to v kontejnerech potreba
- nebo muzeme poustet generovani + podepisovani certifikatu manualne jako Job. Dulezity pro provoz je certifikat, ktery figuruje v NiFi jako CA.
- “root” (CN=Admin, OU=NIFI) uzivatel se nastavuje v konfiguracnim souboru authorizations.xml
- ostatni uzviatele se vytvareji v GUI, stejne tak nastaveni RBAC
- postup vytvoreni uzivatele je nasledujici:
- CN=Admin, OU=NIFI rucne vytvori uzivatele v GUI NiFi (napr. CN=baloun, OU=NIFI) a nastavi mu rucne prava k objektum
- nifi-toolkit vytvori pro uzivatele klientsky certifikat, kde Subject je: CN=baloun, OU=NIFI, a je podepsany stejnym CA certifikatem, jako NiFi instance.
- vlastnik certifikatu si certifikat importuje do browseru, a jakmile se prihlasuje na libovolny endpoint NiFi clusteru, overi se timto certifikatem proti identite CN=baloun, OU=NIFI a prideli se mu prava podle RBAC.
- Identity uzivatelu jsou schovane v souboru users.xml a RBAC v souboru autorizations.xml, ktere se pregenerovavaji (jednak, podle nastaveni v authorizers.xml, to je inicialni config, druhak jakmile se prida/odebere identita, nebo RBAC pravidlo)
- Ma smysl udrzovat persistentne soubory  authorizations.xml,  users.xml,  flow.xml.gz
- Soubor authorizers.xml bych videl idealne jako ConfigMapu

celkem dost bodiku, podivame se na to jak je to implementovane v helm chartu







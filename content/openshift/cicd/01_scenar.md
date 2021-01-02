# ÚVOD 
Seznameni co vlastne chceme probrat, proc a jak a dostat se az ke gitopsu nejakym oslim mustkem
+ LEGACY deployment jak je na hovno
+ DEVOPS jako super ale nešlo by to udělat ještě lépe?
+ obrázek CICD pipeline kde jako CD je GITOPS a trochu se nad tím zastavit

# Co to je GITOPS?
{{< figure src="img/procchtitgitops.png" caption="proc chtit gitops" >}}
+ GITOPS je workflow  
+ Stav aplikace nebo infrastruktury je plně reprezontován obsahem gitového repožitáře. Jakékoliv změny v repozitáři
  jsou tak automaticky promítnuty do odpovídajícího stavu aplikace nebo infrastruktury.  
+ GITOPS je v CI/CD pipelině ta CD část.  
+ GITOPS je "svatý grál" DevOPSu. (to jsem někde četl nebo slyšel ale líbí se mi to)  
+ Infrastructure as DATA (manifesty) vs infrastucture as CODE(imperativností)  ---> tuhle část více rozvést  
+ GITOPS jsou specifické systémové operace (OPS) navázané na GIT


# Zmínit, prostě někde zahrnout
+ z pohledu vývojáře pouze push a pull requesty
+ GIT jako zdroj pravdy a zároveň mechanismus pro deploy
+ rozdíl mezi deklarativností a imperativností
+ proč je deklarativnost vhodná 
+ GITOPS použitím lastností GITU vytváří level konzistence který je těžký vytvořit jinak 
+ Vypíchnout to že s GITEM jsou vlastně všichni tak nějak seznámeni, tím pádem vlastní workflow když opomenu nutnost vytvářet manifesty je vlastně známá věc

# tooling
{{< figure src="img/tools.png" caption="tools" >}}
+ jaké jsou možnosti a jaký nástroj vlastně hledáme
+ popsat jak by takový nástroj měl fungovat a že vlastně dělá jenom synchronizaci stavu git repozitáře promítnutého do stavu infrastruktury/aplikace  = continuous delivery
+ jaké pomocné nástroje použijeme tak abychom nemuseli neustále vše duplikovat (helm, kustomize, openshift template --> ty myslím že budou brzy obsolete)

# GITOPS výzvy
+ secrets management
+ závislosti mezi deploymenty (CRD first ...)
+ integrace mezi CI nástroji  (tedy CI-->CD)
+ storage provisioning (dynamic vs manual, disaster, permisions)
+ nedeklarativní požadavky

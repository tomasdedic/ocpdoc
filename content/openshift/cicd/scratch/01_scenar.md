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

# Michalovi poznamky

+ Cesta ke GitOps 
  Ukázat, jak se měnil deployment. Ideálně formou zužujícího se deployment postupu s vizuálním zobrazením.   
  Jak vypadá tradiční deployment?   
Obrázek ukazující složitý instalační postup, kde je mnoho vstupu lišící se dle prostředí a mnoho prostoru pro chyby. Klikací a se screenshoty 😊 
První krok k automatizaci 
Deployment skripty s response file (unattendant deployment). 
Výhody: 
TBD 
Stále nevýhody - každý tým samostatně: 
udržuje store pro releasy 
udržuje store pro per-env konfiguraci 
udržuje deployment stanici, nebo řešit problémy na osobních stanicích, proč něco nefunguje 
CD pipeline 
Popis: TBD, zatím bez cílení na kontejnery 
Obrázek: TBD – CD pipeline, zatím bez cílení na kontejnery 
Výhody (nutno přeformulovat): 
Centrální úložiště distribučních artefaktů 
Centrální úložiště konfigurace 
Centrální úložiště citlivých dat (hesla apod.) - ideálně :-) 
Centrálně definované CD postupy a spravovaná CD pipeline 
Pro spuštění deploymentu není nutné mít oprávnění na cílové systémy 
Audit – lze určit, kdo nasadil danou verzi 
Možnost provádět dodatečnou QA – security scan apod. 
Možnost provádět evidenci verzí 
Lze integrovat s provozním deníkem 
Napojení na integrační testy 
Sdílená codebase (jakože Jenkins knihovna) - popsat jinak :-) 

TBD - výhody GIT (audit, oprávnění, centrální správa) 

TBD - další, více rozepsat, přeformulovat, rozdělit 

Tady se zastavit s tím, že takto dnes vypadá ideální deployment 

A můžeme to ještě zjednodušit? 

Tady bych napsal nevýhody CD pipeline dle předchozího, ale opatrně 😊 

Nutnost spouštět manuálně 

Pořád riziko, že se zapomene na nějakou komponentu 

Nevhodné pro častější releasy 

Cesta k ideálnímu scénáři - sem bych dal takovýto, že vývojář udělá commit, čímž se spustí kompletní testy a pokud projdou, tak se aplikace automaticky nasadí do produkce. - Tady obrázek kombinace CI + CD. 

Toto je hodně odvážné, v mnoha prostředích spíše z kategorie sci-fi 😊, ale některé prvky je možné implementovat. 

Co kdyby deployment vypadal takto? 

A tady obrázek gitops deploymentu, postupně zazoomovat na jednotlivé kroky, co obsahují. 

Potom spustit video - reálný deployment - zjednodušeně (ideálně s piktogramy a textem, aby bylo jasné, co kdo zrovna dělá) a velmi zrychleně - WOW efekt. Krátký (max 1 minutu). Bez mluvení, ideálně nějaká vhodná hudba. 

Pojďme se podívat na jednotlivé kroky. 

A tady bych spustil video (detailnější) v normální rychlosti, bez piktogramů a textu (jen přeskočil prodlevy) s tím, že u toho budeme detailně popisovat. Bude se pauzovat video, kde bude potřeba. Na druhou stranu je dobré, aby se celou dobu mluvilo (max krátké přestávky). Z videa musí být určitě zřetelné kde se kliká, zvýraznit důležité prvky a zvýraznit (příp. zazoomovat) o čem se zrovna mluví. 

 

DO TASKU PRIDAT VSTUPY OD GARTNERU 

A lze použít i na infrastrukturu 
Jako spojení DevOps a Infrastructure As Code (resp. Everything as Code) 
https://github.com/redhat-developer/kam/blob/master/docs/README.md 
Zvážit, ve kterém okamžiku zacílit čistě na kontejnery 
Zvážit, jak moc zmiňovat CI - určitě na začátku gitopsu s odkazem na to, že se vlastně jedná o principy běžně používané u CI pipeline (automatický build+qa) na základě commitu převedené do CD 
Nakonec, na co je potřeba si dát pozor a co je potreba vyresit 
GIT musí pořád běžet, musejí být správně nastavena práva, … 
Storage 
Podepisovani commitu 

## Why
As a software organization, I would like to:

Audit all changes made to pipelines, infrastructure, and application configuration.
Roll forward/back to desired state in case of issues.
Consistently configure all environments.
Reduce manual effort by automating application and environment setup and remediation.
Have an easy way to manage application and infrastructure state across clusters/environments.

## What
GitOps is a natural evolution of DevOps and Infrastructure-as-Code.
GitOps is when the infrastructure and/or application state is fully represented by the contents of a git repository. Any changes to the git repository are reflected in the corresponding state of the associated infrastructure and applications through automation.
## Principles
Git is the source of truth.
Separate application source code (Java/Go) from deployment manifests i.e the application source code and the GitOps configuration reside in separate git repositories.
Deployment manifests are standard Kubernetes (k8s) manifests i.e Kubernetes manifests in the GitOps repository can be simply applied with nothing more than a oc apply.
Kustomize for defining the differences between environments i.e reusable parameters with extra resources described using kustomization.yaml.

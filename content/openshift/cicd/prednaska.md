# Mluvení
Dobrý den, mé jméno je ... a s kolegou ... bychom vám dnes povídali o GITOPS.  
GITOPS je slovo které poslední dobou dost ve světě Kubernetes a cloud native technologií rezonuje. Proto 
jsme se rozhodli udělat tuto prezentaci a pokusit se definovat co to vlastně GITOPS je, jakých částí
se týká, projít si jeho workflow a také tooling potřebný pro úspěšné zvládnutí této disciplíny.Na závěr předvedeme krátké demo, 
které abstrakci předvede na konkrétním příkladu. Doufejme že mlha trochu opadne a stromy pak budou zřetelně vidět.
  
  
**Čeho se vlastně GITOPS týká?**  

## Legacy deployment
Vrátíme se těd trochu v čase do doby bez virtualizace a kontejnerů. Budeme té době říkat třeba "legacy". Někteří z vás pamatují na nasazovování nových
releasů na servery které byli ve farmě nebo nějaké z podob clusteru.  
Developeři provedli release, release většinou obsahoval nějakou příručku co všechno se má pro deploy upravit.
Tento release se nějakým způsobem dostal k administrátorům. Ti měli nějakou vlastní přiručku kde bylo popsáno jak se vlastně nasazuje, co je vše potřeba odstavit, pořadí a pak nějaké ty testy funkčnosti.  
No a každá tahle činnost se pak měla zopakovat xkrát v závislosi na množství serverů. Většinou ještě v nějakém odstávkovém čase, velice často v "příjemných" večerních hodinách. Nechci ten příběh uplně rozvíjet ale jistě si dovedete představit nebo máte nějakou zkušenost jak obrovský tam byl prostor pro chyby.  
Samozřejmě automatizovalo se i v té době a né vše bylo špatné jak by se mohlo zdát, určitě se dalo dobře vymyšleným a alikovaným postupem dosáhnout uspokojivých výsledků. Tento příklad je trochu přitažený za vlasy ale chceme poukázat na možné rozdíly.  

Proces by se dal vystihnout nějak následovně. Myslím že obrázek je vcelku samopopisný.  

>img#1

Tady je asi na čase podívat se na význam sousloví CI/CD pipeline a trochu si definovat co je v něm obsaženo.
CI/CD tedy continous integration a continous deployment definujeme jako soubor operačních principů a praktik které napomáhají  
nasazení častých změn v kódu.  
Je to vlastně průběžná automatizace a monitoring přez celý životní cyklus aplikace - od integrace a testů po delivery fázi a nasazení.   
Implementace těchto sousledných principů se pak nazývá "CI/CD pipeline".  
Tolik k definicím.  
Vlastně jsme tímto názvoslovím předběhli dobu v které se teď pohybujeme, ale určitá společná synergie a korelace se tam dá najít a abychom měli s čím porovnávat další části usadíme i do obrázku.

Jako CI může být brán třeba i kompilace lokálně a následné publikování artefaktu na sdílené úložiště společně s generováním dokumentace, také to je v jisté formě pipeline i když třeba může postrádat komplexní automatičnost.  
CD je pak proces delivery artefaktů a nasazení do prostředí, opět to může být manuální nasazení kdy je krok po kroku aplikována dokumentační nebo třeba release příručka s určitou formou automatizace (deploy skript ...).   

Nevýhody tohoto postupu jsou zřejmé.  
+ jenotlivá prostředí se mohou architektonicky i konfiguračně lišit, je tedy potřeba mít tento stav zachycen ve styčných plochách  
+ Každý tým pracuje samostatně, mezi developerem a adminem je poměrně velká zeď.  
+ Je potřeba udržovat a dodržovat dokumentační příručku.  
+ Je potřeba udržovat stanici pro deployment nebo řešit problémy na osobních stanicích.  
+ Pokud docházelo k častým změnám kódu a tedy častým releasům mohl být problém s nasazením  

## Přichází DevOPS (development and system operations)

Jak čas šel tak se rozvíjeli automatizační nástroje, integrace mezi jednolivými částmi procesu se prohlubovala a tím se  bouraly zdi.  
Disciplína která by měla vztyčit most mezi DEV a OPS zvaná nečekaně DEVOPS začala nabírat na důležitosti.  

Nechtěl jsem vymýšlet svojí definici tak tady je jedna co jsem našel na internetu. Je téměř jisté že si pod tím pojmem každý něco představíte, možná každý něco maličko jiného ale to vůbec nevadí.  
**Můj kulhavý překlad definuje DevOps jako sadu ideí, principů, technologie a procesů které usměrňují a usnadňují proces vývoje.**
To je značně obecná definice a naplňování ideí je rozdílné a můžeme říci i značně heterogenní, tomu odpovídají i procesy a tooling  
  
{{< figure src="img/devops.png" caption="devops workflow" >}}
Na obrázku je pro příklad jedna CI/CD pipeline která ukazuje cestu od vývojáře až po deploy do Kubernetes clusteru.  
Myslím že CI část je celkem zřejmá, ale zaměříme se na část CD (tedy continous DELIVERY).  
Jako CD část může být vlastně cokoliv co nějakým způsobem dostane náší aplikaci do clusteru, nejčastěji jsou v rámci CI části vygenerovány nebo upraveny  k8s manifesty nebo třeba vygenerovány nějaké "values" které jsou následně do kubernetes aplikovány.  
Vlastně je tenhle diagram v pořádku a dělá tak nějak přesně to co by dělat měl.  
Jen pokud si to trochu představíte chybí tam nějaká část která by chrakterizovala stav aplikace, jak byla nasazena s jakými parametry  
a také jistota že aplikace v tomto stavu v clusteru skutečně běží (resp je do tohoto stavu rekonsilována).  

## přichází GITOPS
Co nám vlastně chybí ke štěstí a čeho bychom chtěli dosáhnout?  

+ všechny změny v infrastruktuře a aplikaci jsou auditované  
+ v případě problému jednoduchý rollback případně rollforward  
+ všechny prostředí mají zajištěnou konzistentní konfiguraci  
+ snížit množství manuálních činností automatizovaným nasazováním aplikací a konfigurací prostředí  
+ jednoduchý způsob správy aplikací a infrastruktry přez více prostředí  

GITOPS nepřináší žádnou velkou revoluci, vše co dělá se dá dosáhnout i v jinak definované CD pipelině.  
Ale proč nepoužít něco s čím mají vývojáři a administrátoři praktické zkušenosti?  

Gitops vlastně říká že stav aplikace nebo infrastruktury je plně reprezentován stavem gitového repozitáře. Všimněte si slova infrastruktura, ano i infrastruktura může být reprezentována obsahem gitového repozitáře.  


Z předchozích definic je GITOPS vlastně specifické systémové operace (OPS) navázané na GIT.   
Z pohledu pipeline je to to Continous deployment(CD) tedy jakým způsobem promítneme stav v repozitáři do stavu v clusteru.   
Pro začátek si to můžeme představit jako "udělám pull request do GITU s manifesty a magic happend", tedy dojde k vytvoření příslušných zdrojů na clusteru.  
Tady se trochu pozastavíme nad obrázkem a opět se více zastavíme nad CD částí.
{{< figure src="img/gitops.png" caption="gitops workflow" >}}

Je potřeba si uvědomit že GITOPS je primárně o workflow, GIT workflow, template workflow, secret management workflow ... všechny tyto části
Velká výhoda je že vlastně není potřeba nic velkého se učit jak pro vývojáře tak pro administrátory.   
Práce s GITEM je "tak nějak"  a dá se v podstatě omezit na použití push a pull request.  


## proč GITOPS a kontejnery jsou tak dobrá kombinace chutí
Gitops přístup  se dá využít i pro tradiční prostředí.  
Imperativnosti kterou je dosaženo nativními prostředky kubernetes clusteru (scheduler, operátory a podobně) bude v tradičním prostředí potřeba dosáhnout jiným způsobem automatizace nebo skriptováním.

+ kubernetes jsou nativně deklarativní prostředí  
Deklarujeme stav který chceme dosáhnout jak pro aplikace tak pro infrastrukturu a cluster se pokusí svými vnitřními prostředky tohoto deklarovaného stavu dosáhnout  
+ k8s manifests
Yaml soubory jsou plaintextové a tedy jednoduše uložitelné v GITU
+ manifesty jsou aplikovány standartními kubernetes prostředky  
Tedy i z pohledu synchronizačního nástroje budou aplikovány stejným, standartním způsobem.  
+ kubernetest temlate tooling (helm, kustomize)

## sync tool a support tools
Vlastně celá věc o kterou je GITOPS opřený je nějaký výkonný nástroj, který by řešil synchronizaci mezi repozitářem a runtime prostředím.  
+ jaké jsou možnosti a jaký nástroj vlastně hledáme
--> popsat jaké má vlastnosti
+ popsat jak by takový nástroj měl fungovat a že vlastně dělá jenom synchronizaci stavu git repozitáře promítnutého do stavu infrastruktury/aplikace  = continuous delivery
+ jaké pomocné nástroje použijeme tak abychom nemuseli neustále vše duplikovat mezi cílovými prostředími (helm, kustomize) 
{{< figure src="img/tools.png" caption="tooling" >}}


# Mluvení
Dobrý den, mé jméno je ... a s kolegou ... bychom vám dnes povídali o GITOPS.  
GITOPS je slovo které poslední dobou dost ve světě Kubernetes a cloud native technologií rezonuje. Proto 
jsme se rozhodli udělat tuto prezentaci a pokusit se definovat co to vlastně GITOPS je, jakých částí
se týká, projít si jeho workflow a také tooling potřebný pro úspěšné zvládnutí této disciplíny.Na závěr předvedeme krátké demo, 
které abstrakci předvede na konkrétním příkladu. Doufejme že mlha trochu opadne a stromy pak budou zřetelně vidět.
  
  
Čeho se vlastně GITOPS týká?
##Legacy deployment
Vrátíme se těd trochu v čase do doby bez virtualizace a kontejnerů. Budeme té době říkat třeba "legacy". Někteří z vás pamatují na nasazovování nových
releasů na servery které byli ve farmě nebo nějaké z podob clusteru.  
Developeři provedli release, release většinou obsahoval nějakou příručku co všechno se má pro deploy upravit.
Tento release se nějakým způsobem dostal k administrátorům. Ti měli nějakou vlastní přiručku kde bylo popsáno jak se vlastně nasazuje, co je vše potřeba odstavit, pořadí a pak nějaké ty testy.  
No a každá tahle činnost se pak měla zopakovat xkrát v závislosi na množství serverů. Většinou ještě v nějakém odstávkovém čase, velice často v "příjemných" večerních hodinách. Nechci ten příběh uplně rozvíjet ale jistě si dovedete představit nebo máte nějakou zkušenost jak obrovský tam byl prostor pro chyby.  
Samozřejmě automatizovalo se i v té době a né vše bylo špatné jak by se mohlo zdát, tento příklad je trochu přitažený za vlasy ale chceme poukázat na možné rozdíly.
##Přichází DevOPS (development and system operations)
{{< figure src="img/devops.png" caption="devops workflow" >}}
Jak čas šel tak se rozvíjeli automatizační nástroje, zároveň se trochu bourala zeď mezi DEV a OPS no a pak přišel Kubernetes se svým deklarativním přistupem. Disciplína zvaná DEVOPS začala nabírat na důležitosti.
> tady nevim jak to uvést:
> DevOps is a collaborative culture with a set of practices, ideas, tools, technologies, and processes that streamline the product development process. 
> CI/CD is a collection of operating principles and practices that help development teams to deliver frequent code changes reliably. It is the ongoing automation and monitoring throughout the application life cycle - from integration and testing to product delivery and deployment phases. The implementation of these practices, also known as the “CI/CD pipeline”
> Continuous Integration usually refers to integrating, building, and testing code within the development environment. Continuous Delivery builds on this, dealing with the final stages required for production deployment.
## navazuje GITOPS
{{< figure src="img/gitops.png" caption="gitops workflow" >}}
No a proč vlastně nepoužít GIT jako úložiště 
Z předchozích definic je GITOPS vlastně specifické systémové operace (OPS) navázané na GIT. Z pohledu CI/CD je to to CD za lomítkem tedy Continous
deployment. Pro začátek si to můžeme představit jako "udělám commit do GITU a magic happend", tedy dojde k vytvoření příslušných zdrojů.
Tady se trochu pozastavíme nad obrázkem **image s pipeline** a popíšeme si jednotlivé kroky.




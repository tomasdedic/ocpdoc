---
title: "GitHub actions review"
date: 2020-06-03 
author: Tomas Dedic
description: "Desc"
lead: "working"
categories:
  - "GIT"
tags:
  - "GIT"

---
Postřehy z PoC GitHubu v kontextu České spořitelny.

### GitHub-Hosted Runners
běží v Azure
mají password-less roota, tzn funkční sudo apt install atd
jsou jednorázové - VM se po doběhnutí zahodí
mají nodejs a Docker
mají předcachované nějaké docker image a nejrůznější běžně používané balíky pro zlepšení performance (a šetření zdrojů MS :)
jsou hostované v USA
jsou placené, ale náklady nejsou drasticky vysoké, a můžeme jich mít nárazově kolik chceme
GH garantuje latest security patche atd.

### Self-Hosted Runners
Je třeba udržovat hosty, může být X instancí na hosta
Statická registrace, tedy i počet runnerů
Stahuje se binárka z webu ručně, ale pak se umí sama aktualizovat
workflow musí obsahovat runs-on: self-hosted (je to label, můžeme si definovat vlastní)
podle mých pozorování se shell skripty pouští přímo na hostu, bez chrootu nebo jiných omezeních (pozn: tohle odpovídá pokud vím TeamCity)
je možné používat tooling z hostu, ale to dělá workflow zcela nepřenosné a je to antipattern - správné je používat Actions, případně si psát vlastní

### User Experience
Chybí možnost spustit Workflow manuálně, natož s parametry. Jediná možnost je zobrazit si detail již ukončeného běhu a ten restartovat.
Možnost “pustit nad větví” prostě není. Právě tato chybějící možnost prakticky znemožňuje použití pro jakoukoliv automatizaci, a bude otravovat život úplně všem.
UI není zas tak moc user-friendly, sem tam mi chybí nějaký proklik, nebo shrnutí - neexistuje třeba na webu overview všech workflow, které mohu vidět, ideální by to bylo dle teamu.
Pokud omezíme Marketplace (což je otázka, jestli to skutečně dává smysl, je to podobné, jako když používáme Maven pluginy, a ty také newhitelistujeme), UI stejně hledá v celém Marketplace
Není možnost Workflow pozastavit a pokračovat na manální akci - tohoto se dá dosáhnout pouze přes vytvoření PR v rámcí původního Workflow nad jiným repository/branch, a po jeho manálním schválením pokračovat tam.
To může vést na lepší design celého CI, ale je to složitější, a chybí pak náhled na celou pipeline.
Nenasel jsem jednoduchý způsob, jak držet konfigurace napříč různými workflow ve stejném repu, jediná možnost je Secret (kde se ale nedá podívat na hodnotu). Dá se manuálně načíst JSON/YAML soubor z repa.

### Questions for GitHub
Některé body jsou duplicitní k předchozím postřehům (záměrně).

+ What is a security model for self-hosted runners?
+ Is action code executed in sandbox, chroot, container, or at least random uid?
+ And same for raw shell commands?
+ Is there a way to prevent PRs outside organization from being executed on self-hosted runners? (note PRs from inside the organization are fine). This is an important security request, disabling Actions for all public repositories is a very thin security barrier (and limits usability).
+ Is it a supported way to auto-register new runners?
+ I did not find any configuration for whitelisting actions from the marketplace - only setting to limit execution to local actions. Is this correct? During the initial presentation, it was stated that whitelisting is possible.
+ The permission config for Actions states: "Enable local Actions only for this organization; This allows all repositories to execute any Action as long as the code for the Action exists within the same repository." However it seems that it actually allows Actions "within the same organization". Is this correct, and the description on the website is actually wrong?
+ When organization is limited to local actions only,  even "actions/checkout" is blocked, it is forcing us to actually fork "built-in" actions as well, is this correct? Adding "actions/*" as allowed actions even with local action limitation would be helpful.
+ There is no way to execute workflow manually, ideally with custom parameters (something like Jenkins pipeline with parameters) - this is very useful for automation, and this missing feature greatly decreases Actions usability across organization (and started to be annoying in about 2 hours of experimenting with Actions).
+ At least start on revision/branch/tag on choice is needed. Example use-case: I’ve accidentally deleted binary artifact from repository and need to rebuild it, and that from specific tag X.Y.
+ When job is re-run, the previous run logs (but also information that it executed and when) are lost forever. Expected behavior is to generate new execution entry.
+ Looks like there is still no way for manual approvement during workflow execution (I have found this  https://github.community/t5/GitHub-Actions/GitHub-Actions-Manual-Trigger-Approvals/td-p/31504/highlight/true). A lot can be accomplished by chaining workflows via making PRs, but not everything. When chaining workflows, there is now overview of the whole process.
+ UX: When organization is limited to local actions only, Marketplace still searches everything, without any warning, and fails on execution. Best behavior in this case seems like searching allowed actions only, with a button to extend the search globally, outside organization. Are there any plans to improve this?
+ UX: When editing a pipeline, if I copy action identification (e.g. "docker/build-push-action@v1.1.0"), it does not find the said action. This is annoying, since there is no easy way to view documentation for already used action. It obviously searches only for human-readable names, and not the action IDs.
+ UX: It would be nice to have all Workflows view in Team view (for all its repositories).
+ UX: Are there plans to support non-Secret configurations? Just like K8s have secrets and configmaps.
+ UX: Missing simple features, like getting tag/branch name without refs/ prefix, see discussion here https://github.community/t/how-to-get-just-the-tag-name/16241

#### Summary
Points 7-9 decreases usability in our use case to the point where it is unacceptable as replacement for classic CI tools, acting only as “scriptable webhooks”.
Point 2 (foreign PRs being executed on local infrastructure) is great security concern, which might prevent use within our organization. And we do need self-hosted runners to execute tests in local network.


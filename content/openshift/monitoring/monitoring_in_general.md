---
title: "UserWorkload Monitoring"
date: 2023-09-05
author: Tomas Dedic
description: "UserWorkload Monitoring in general"
lead: "working"
categories:
  - "Openshift"
tags:
  - "Monitoring"
toc: true
---
# User Workload Monitoring

## **Úvod**

Pro monitoring aplikací (workloadu) se používá termín "user workload monitoring".
 Nastavení monitoringu a alertingu pro aplikace v OCP je součástí deploye jednotlivých aplikací.
 Nastavení se provádí vytvořením objektů v rámci projektu (namespace), ve kterém se nachází aplikace.

## **Stručný popis toho co je k monitoringu třeba**

- Aplikace exportuje metriky v prometheus formátu
- Endpoint je dostupný pro user-workload instanci promethea (mělo by být by-default - není potřeba řešit, jen když sběr metrik nefunguje)
- Definice pro sběr metrik Prometheem - objekt typu **ServiceMonitor** nebo **PodMonitor**
- Vytvoření Grafana dashboardu pro zobrazení vybraných aplikačních metrik - objekt typu **GrafanaDashboard** (optional)
- Vytvoření alertovacích pravidel pro vybrané metriky - objekt typu **PrometheusRule** (optional)

## **Prerekvizita - export metrik**

Pro monitoring aplikačních metrik se používá technologie Prometheus.
 Nutnou prerekvizitou pro monitoring aplikace je, aby aplikace vystavila/exportovala metriky v Prometheus formátu, více informací např. zde [Exposition formats | Prometheus](https://prometheus.io/docs/instrumenting/exposition_formats/).
 Buďto tento formát podporuje samotný aplikační runtime a nebo je možné použít tzv. exporter, viz. dokumentace zde: [Exporters and integrations | Prometheus](https://prometheus.io/docs/instrumenting/exporters/)

 Je nutné znát endpoint, na kterém jsou metriky vystaveny. Tedy port a cesta.
 Best practice je nevystavovat metriky otevřeně ven z clusteru, tedy pokud má aplikace routu, tak:
          a) vystavit metriky na jiném portu než je používán pro routu
          b) pokud budou vystaveny metriky přes routu, měl by endpoint podléhat ověření, např. přes oauth proxy

## **Sběr metrik**

Pro nastavení sběru metrik Prometheem (tzv. scraping), je potřeba vytvořit objekt typu _ **ServiceMonitor** _ nebo _ **PodMonitor.** _
Tyto objekty definují parametry pro výběr podů pro disvcovery targetů pro scraping metrik a zároveň parametry endpointů na vybraných podech, kde jsou metriky exportovány.
 Z těchto informací pak prometheus po provedení discovery složí kompletní URL targetů na jednotlivé pody ze kterých pak probíhá scraping.

### ServiceMonitor vs. PodMonitor

- ServiceMonitor - discovery podů se provádí na základě parametrů pro výběr objektů typu Service a funkčních endpointů (podů) na dané službě.
- PodMonitor - disocvery podů se provádí na základě parametrů pro výběr objektů typu Pod.

Tedy u objektu ServiceMonitor říkáme - vyber všechny pody, které obsluhují služby, které odpovídají těmto kritériím - vybíráme tedy na základě služeb, kdy můžeme jedním objektem ServiceMonitor vybrat více služeb.
 U objektu PodMonitor říkáme - vyber všechny pody, které odpovídají těmto kritériím - vybíráme tedy na základě podů, kdy můžeme jedním objektem PodMonitor vybrat více podů.

 V obou případech je výsledkem na základě discovery procesu seznam targetů - konkrétních podů. Tedy i v případě objektu typu ServiceMonitor se scraping metrik provádí ze všech podů, které obsluhují danou službu.

### Použití ServiceMonitor nebo PodMonitor

V případě, že ke službě existuje odpovídající objekt typu Service, doporučuje se použít ServiceMonitor.
 V případě, že deployment nevyžaduje objekt typu Service, pak je možné použít PodMonitor.

### ServiceMonitor - příklad

- spec.selector - vybírá Service na základě matchLabels a nebo matchExprression
- spec.endpoints.port - název portu na objektu typu Service

**ServiceMonitor**
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  labels:
    app: app-1
  name: app-1-service-metrics
  namespace: app-1
spec:
  endpoints:
  - interval: 30s
    port: input
    scheme: http
    path: "/metrics"
  selector:
    matchLabels:
      app: app-1
```
### PodMonitor - příklad

- spec.selector - vybírá pod na základě matchLabels a nebo matchExprression
- spec.podMetricsEndpoints.port - název portu na podu

**PodMonitor**
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  labels:
    team: frontend
  name: app-1-pod-metrics
  namespace: app-1
spec:
  selector:
    matchLabels:
      app: app-1
  podMetricsEndpoints:
  - port: web
    scheme: https
    path: "/metrics"
```
## **Zobrazení metrik, Grafana dashboards**

Metriky je možné zobrazit ad-hoc v OCP console, v menu Observer \> Metrics za použití dotazů ve formátu PromQL.
 Alternativně v GUI Thanos Querier, taktéž za použití PromQL dotazů.
 Více o PromQL dotazovacím jazyku viz. např. zde: [Querying basics | Prometheus](https://prometheus.io/docs/prometheus/latest/querying/basics/).

Pro pravidelné zobrazování/sledování vybraných aplikačních metrik, je možné založit v Grafaně vlastní dashboard.
 Grafana pracuje na pozadí s definicí dashboardu uloženou v JSON formátu, více viz. zde: [JSON model | Grafana Labs](https://grafana.com/docs/grafana/latest/dashboards/json-model/).
 Můžete si najít a stáhnou existující dashboard, např. v komunitní galerii [Dashboards | Grafana Labs](https://grafana.com/grafana/dashboards/).
 Nebo si můžete vytvořit vlastní dashboard, ať ručně přímo v JSON a nebo v GUI grafana a pak exportovat do JSON.

Jakmile máte grafana dashboard v JSON formátu, můžete jej přidat do grafany pomocí CR objektu typu GrafanaDashboard.
 Po založení tohoto objektu dojde k jeho načtení do grafany pomocí operátora.
 Dashboard bude založen ve složce, která nese název projektu (namespace).
 Název a ID dashboardu v rozhraní grafany je součástí JSON definice dashboardu.

### GrafanaDashboard - příklad

- JSON definice grafana dashboardu je víceřádková hodnota klíče **_spec.json_**
- Celá JSON definice (všechny řádky) musí být v YAML odsazena o přesně 4 mezery, tedy tak, aby to bylo správně parsováno jako víceřádková hodnota klíče **_spec.json_**

**GrafanaDashboard**
```yaml
apiVersion: integreatly.org/v1alpha1
kind: GrafanaDashboard
metadata:
  name: dashboard-app-1
  namesapce: app-1
  labels:
    app: grafana
spec:
  json: >
    {
      "__inputs": [
        {
          "name": "DS_PROMETHEUS",
          "label": "prometheus",
          "description": "",
          "type": "datasource",
          "pluginId": "prometheus",
          "pluginName": "Prometheus"
        }
      ],
      "__elements": [],
      "__requires": [
    ...
```

## **Alerting**

V případě, že je žádoucí na základě vybraných aplikačních metrik vyhodnocovat varování při definovaných hraničních hodnotách, pak je možné nastavit tzv. alerting rules.
 Tato konfigurace definuje podmínky na základě kterých budou založena uživatelská pravidla, tzv. Prometheus rules, na základě kterých jsou vyhodnocovány alerty.
 Objekt, kterým se definují tato pravidla je objekt typu **PrometheusRule**.

Alerty lze sdružovat do skupin - **rule groups**. Všechna pravidla v jedné skupině jsou zpracována sekvenčně. Všechny skupiny jsou zpracovány paralelně.

Alert Description by měl obsahovat:

- na začátku stručnou identifikaci služby/deploymentu/podu - tedy aby bylo jasné, jaké služby/aplikace se problém týká,
- dále popis projevu problému
- a doporučené akce jak problém řešit

Případná další doporučení na vytváření alertovacích pravidel můžete najít v dokumentaci: [https://docs.openshift.com/container-platform/4.9/monitoring/managing-alerts.html#Optimizing-alerting-for-user-defined-projects\_managing-alerts](https://docs.openshift.com/container-platform/4.9/monitoring/managing-alerts.html#Optimizing-alerting-for-user-defined-projects_managing-alerts)

### PrometheusRule - příklad

- spec - celá část definice je ve formátu definice Alerting Rules - viz. dokumentace: [Alerting rules | Prometheus](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/)
- spec.groups - seznam rule groups
- spec.groups[].name - jméno rule group
- spec.groups[].interval - jak častou jsou pravidla ve skupině vyhodnocována - optional - default: global.evaluation\_interval
- spec.groups[].rules - seznam pravidel v rámci jedné skupiny
- spec.groups[].rules[].alert - název alerting rule
- spec.groups[].rules[].expr - obsahuje podmínku na základě které je vyhodnocen alert
- spec.groups[].rules[].for - umožňuje definovat čas po který musí daný alert trvat (ve stavu Pending), než je vyhlášen alert (Firing) - optional
- spec.groups[].rules[].labels.severity - umožňuje definovat důležitost - info | warning | critical (volitelné, ale doporučené; alternativně i jiné custom severitiy levels)
- spec.groups[].rules[].annotations.summary - velmi stručný popis alertu - význam
- spec.groups[].rules[].annotations.description - identifikace služby/deploymentu/podu a popis alertu, jak ho chápat v době, kdy došlo k vyhodnocení alertu jako Firing (aktivní), případně doporučené akce

**PrometheusRule**
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: alert-app-1
  namespace: app-1
spec:
  groups:
  - name: app-1
    rules:
    - alert: JdbcConnIdle2
      expr: jdbc_connections_idle{job="app-1"} > 5
      for: 1m
      labels:
        severity: warning
      annotations:
        summary: "Number of idle JDBC connections"
        description: "APP-1: Container {{ $labels.container }} has more idle connections (current value: {{ $value }} then 5 connections."
```


# Génère le dashboard Grafana « RedOne – Centre de supervision sécurité »
import json, sys

PROM = {"type": "prometheus", "uid": "prometheus-clamav"}
LOKI = {"type": "loki", "uid": "loki-clamav"}
SRV = 'host=~"$serveur"'
WZ = 'job="wazuh", agent=~"$agent"'
LV_MOY = '[7-9]|1[01]'
LV_CRIT = '1[2-5]'
# Extraction niveau / description / n° de règle par expression régulière (fonctionne aussi sur les alertes tronquées)
RULE = r'| regexp `"rule":\{"level":(?P<niveau>\d+),"description":"(?P<description>(?:[^"\\]|\\.)*)","id":"(?P<id>\d+)"` '

panels = []
_id = [0]
_pos = {"x": 0, "y": 0, "h": 0}


def nid():
    _id[0] += 1
    return _id[0]


def place(w, h):
    if _pos["x"] + w > 24:
        _pos["x"] = 0
        _pos["y"] += _pos["h"]
        _pos["h"] = 0
    g = {"x": _pos["x"], "y": _pos["y"], "w": w, "h": h}
    _pos["x"] += w
    _pos["h"] = max(_pos["h"], h)
    return g


def newline():
    if _pos["x"]:
        _pos["x"] = 0
        _pos["y"] += _pos["h"]
        _pos["h"] = 0


def row(title):
    newline()
    p = {"id": nid(), "type": "row", "title": title, "collapsed": False, "panels": [], "gridPos": place(24, 1)}
    panels.append(p)
    newline()


def text(md, w=24, h=4, title=""):
    panels.append({"id": nid(), "type": "text", "title": title, "gridPos": place(w, h),
                   "options": {"mode": "markdown", "content": md}, "transparent": not title})


def prom(expr, legend="", instant=False, fmt="time_series", ref="A"):
    t = {"refId": ref, "datasource": PROM, "expr": expr, "legendFormat": legend or "__auto",
         "range": not instant, "instant": instant, "format": fmt}
    return t


def loki(expr, legend="", instant=False, ref="A"):
    return {"refId": ref, "datasource": LOKI, "expr": expr, "legendFormat": legend,
            "queryType": "instant" if instant else "range"}


def thr(*steps):
    """steps : couleur de base puis (valeur, couleur)..."""
    s = [{"color": steps[0], "value": None}]
    for v, c in steps[1:]:
        s.append({"color": c, "value": v})
    return {"mode": "absolute", "steps": s}


def stat(title, desc, targets, w=4, h=4, unit="none", th=None, mappings=None, color_mode="background",
         decimals=None, no_value="0", text_mode="value", graph="none"):
    d = {"unit": unit, "thresholds": th or thr("blue"), "color": {"mode": "thresholds"}, "noValue": no_value}
    if mappings:
        d["mappings"] = mappings
    if decimals is not None:
        d["decimals"] = decimals
    panels.append({"id": nid(), "type": "stat", "title": title, "description": desc, "gridPos": place(w, h),
                   "datasource": targets[0]["datasource"], "targets": targets,
                   "fieldConfig": {"defaults": d, "overrides": []},
                   "options": {"reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": False},
                               "colorMode": color_mode, "graphMode": graph, "textMode": text_mode,
                               "justifyMode": "center", "orientation": "auto", "wideLayout": True,
                               "showPercentChange": False}})


def onoff():
    return [{"type": "value", "options": {"0": {"text": "ARRÊTÉ", "color": "red"},
                                          "1": {"text": "ACTIF", "color": "green"}}}]


def ts(title, desc, targets, w=12, h=8, unit="none", stack=False, bars=False, overrides=None, maxv=None,
       th=None, legend_calcs=None, th_style="off"):
    d = {"unit": unit, "color": {"mode": "palette-classic"},
         "thresholds": th or thr("green"),
         "custom": {"drawStyle": "bars" if bars else "line", "lineWidth": 2, "fillOpacity": 70 if bars else 18,
                    "gradientMode": "opacity", "showPoints": "never", "spanNulls": True,
                    "stacking": {"mode": "normal" if stack else "none", "group": "A"},
                    "thresholdsStyle": {"mode": th_style}, "axisSoftMin": 0}}
    if maxv is not None:
        d["max"] = maxv
    panels.append({"id": nid(), "type": "timeseries", "title": title, "description": desc, "gridPos": place(w, h),
                   "interval": "10m" if bars else None, "datasource": targets[0]["datasource"], "targets": targets,
                   "fieldConfig": {"defaults": d, "overrides": overrides or []},
                   "options": {"legend": {"displayMode": "table" if legend_calcs else "list", "placement": "bottom",
                                          "calcs": legend_calcs or [], "showLegend": True},
                               "tooltip": {"mode": "multi", "sort": "desc"}}})


def color_override(name, color):
    return {"matcher": {"id": "byName", "options": name},
            "properties": [{"id": "color", "value": {"mode": "fixed", "fixedColor": color}}]}


def bargauge(title, desc, targets, w=8, h=8, unit="none", th=None, maxv=None, minv=0, mode="gradient",
             color="thresholds", orientation="horizontal", legend="{{agent}}"):
    d = {"unit": unit, "min": minv, "thresholds": th or thr("blue"), "color": {"mode": color}}
    if maxv is not None:
        d["max"] = maxv
    panels.append({"id": nid(), "type": "bargauge", "title": title, "description": desc, "gridPos": place(w, h),
                   "datasource": targets[0]["datasource"], "targets": targets,
                   "fieldConfig": {"defaults": d, "overrides": []},
                   "options": {"reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": True},
                               "orientation": orientation, "displayMode": mode, "showUnfilled": True,
                               "valueMode": "color", "namePlacement": "auto", "sizing": "auto",
                               "minVizHeight": 16, "maxVizHeight": 40}})


def gauge(title, desc, targets, w=6, h=7, unit="percent", th=None):
    panels.append({"id": nid(), "type": "gauge", "title": title, "description": desc, "gridPos": place(w, h),
                   "datasource": targets[0]["datasource"], "targets": targets,
                   "fieldConfig": {"defaults": {"unit": unit, "min": 0, "max": 100, "thresholds": th or thr("green"),
                                                "color": {"mode": "thresholds"}}, "overrides": []},
                   "options": {"reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": False},
                               "showThresholdLabels": False, "showThresholdMarkers": True, "orientation": "auto"}})


def pie(title, desc, targets, w=6, h=8, overrides=None):
    panels.append({"id": nid(), "type": "piechart", "title": title, "description": desc, "gridPos": place(w, h),
                   "datasource": targets[0]["datasource"], "targets": targets,
                   "fieldConfig": {"defaults": {"color": {"mode": "palette-classic"}, "unit": "none"},
                                   "overrides": overrides or []},
                   "options": {"reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": True},
                               "pieType": "donut", "displayLabels": ["percent"],
                               "legend": {"displayMode": "table", "placement": "right", "values": ["value"],
                                          "showLegend": True},
                               "tooltip": {"mode": "single"}}})


def logs(title, desc, targets, w=24, h=9):
    panels.append({"id": nid(), "type": "logs", "title": title, "description": desc, "gridPos": place(w, h),
                   "datasource": targets[0]["datasource"], "targets": targets,
                   "options": {"showTime": True, "wrapLogMessage": True, "sortOrder": "Descending",
                               "enableLogDetails": True, "dedupStrategy": "none", "prettifyLogMessage": False,
                               "showLabels": False, "showCommonLabels": False}})


def table(title, desc, targets, w=12, h=8, transformations=None, overrides=None, defaults=None, no_value=""):
    d = {"custom": {"align": "auto", "cellOptions": {"type": "auto"}, "inspect": False}, "noValue": no_value,
         "thresholds": thr("green")}
    if defaults:
        d.update(defaults)
    panels.append({"id": nid(), "type": "table", "title": title, "description": desc, "gridPos": place(w, h),
                   "datasource": targets[0]["datasource"], "targets": targets,
                   "transformations": transformations or [],
                   "fieldConfig": {"defaults": d, "overrides": overrides or []},
                   "options": {"showHeader": True, "cellHeight": "sm", "footer": {"show": False}}})


def col(name, props):
    return {"matcher": {"id": "byName", "options": name}, "properties": props}


def gauge_cell(unit, th, maxv=100):
    return [{"id": "unit", "value": unit}, {"id": "max", "value": maxv}, {"id": "min", "value": 0},
            {"id": "thresholds", "value": th},
            {"id": "custom.cellOptions", "value": {"type": "gauge", "mode": "gradient", "valueDisplayMode": "text"}}]


TH_RES = thr("green", (70, "orange"), (90, "red"))

# =====================================================================================================
text("""## 🛡️ RedOne – Centre de supervision sécurité
Ce tableau de bord réunit sur **un seul écran** les trois briques de l'AP2 :
**Prometheus** (santé des serveurs) · **ClamAV** (antivirus) · **Wazuh** (SIEM : détection d'intrusion, intégrité des fichiers, conformité CIS).

| Couleur | Signification |
|---|---|
| 🟢 vert | normal, rien à faire |
| 🟠 orange | à surveiller (seuil d'avertissement atteint) |
| 🔴 rouge | incident : intervention nécessaire |

👉 Passez la souris sur l'icône **ⓘ** d'un panneau pour savoir **ce qu'il mesure, d'où vient la donnée et quand réagir**.
Les listes déroulantes en haut filtrent par **serveur** (Prometheus) et par **machine surveillée par Wazuh**.
La période (en haut à droite, 12 h par défaut) s'applique à tous les compteurs « sur la période ».""", w=16, h=9)

text("""| Source | Transport | Stockage |
|---|---|---|
| 🖥️ Serveurs (CPU, RAM, disque) | node_exporter :9100 | **Prometheus** (15 s) |
| 🦠 État ClamAV | métriques textfile | **Prometheus** |
| 🦠 Journaux ClamAV | Grafana Alloy | **Loki** (30 j) |
| 🔐 Alertes Wazuh ≥ 3 | syslog JSON :5514 → Alloy | **Loki** (30 j) |

Grafana interroge **Prometheus** (métriques) et **Loki** (journaux) : aucune donnée n'est stockée dans Grafana.""",
     w=8, h=9, title="D'où viennent les données ?")

# =====================================================================================================
row("🚦 Vue d'ensemble – l'essentiel en 10 secondes")
stat("Serveurs", "Nombre de serveurs qui répondent à Prometheus (node_exporter). "
     "Attendu : 3 (SRV-SUPERVISION, SRV-GLPI, SRV-WAZUH). En dessous : un serveur est éteint ou injoignable.",
     [prom('sum(up{job=~"node|linux"})', instant=True)], w=3, th=thr("red", (2, "orange"), (3, "green")))
stat("Alertes Prom.", "Règles d'alerte Prometheus actuellement déclenchées "
     "(serveur injoignable, CPU > 90 %, RAM < 10 %, disque < 10 %, ClamAV arrêté, signatures > 48 h). Idéal : 0.",
     [prom('count(ALERTS{alertstate="firing"}) or vector(0)', instant=True)], w=3,
     th=thr("green", (1, "red")))
stat("ClamAV", "État du démon clamd (le moteur d'analyse). ARRÊTÉ = plus aucune analyse possible.",
     [prom('clamav_up', instant=True)], w=3, mappings=onoff(), th=thr("red", (1, "green")))
stat("Temps réel", "clamonacc : analyse chaque fichier au moment où il est ouvert ou téléchargé "
     "(dossier Téléchargements surveillé). ARRÊTÉ = un fichier malveillant ne serait détecté qu'au scan hebdomadaire.",
     [prom('clamav_onaccess_up', instant=True)], w=3, mappings=onoff(), th=thr("red", (1, "green")))
stat("Virus", "Nombre de fichiers infectés détectés par ClamAV sur la période "
     "(analyse à la demande, temps réel ou scan hebdo). Le fichier de test EICAR compte aussi.",
     [loki('sum(count_over_time({job="clamav"} |= "FOUND" [$__range]))', instant=True)], w=3,
     th=thr("green", (1, "red")))
stat("Wazuh", "Toutes les alertes Wazuh (niveau ≥ 3) reçues sur la période, toutes machines confondues.",
     [loki('sum(count_over_time({' + WZ + '}[$__range]))', instant=True)], w=3, th=thr("blue"))
stat("Critiques", "Alertes de niveau 12 et plus : attaque par force brute réussie, donnée sensible modifiée, "
     "etc. Chaque alerte de ce niveau doit être analysée.",
     [loki('sum(count_over_time({' + WZ + ', level=~"' + LV_CRIT + '"}[$__range]))', instant=True)], w=3,
     th=thr("green", (1, "red")))
stat("Échecs auth.", "Tentatives de connexion refusées (SSH, Windows, sudo…) vues par Wazuh. "
     "Un pic soudain = tentative de force brute.",
     [loki('sum(count_over_time({' + WZ + '} |~ "authentication_fail" [$__range]))', instant=True)], w=3,
     th=thr("green", (10, "orange"), (50, "red")))

# =====================================================================================================
row("🖥️ Santé des serveurs – Prometheus / node_exporter")
text("""**À quoi ça sert ?** Savoir si les serveurs RedOne ont les ressources pour fonctionner.
Un serveur saturé (CPU, RAM) devient lent ; un disque plein **arrête** les services (bases GLPI, index Wazuh, journaux).
**Seuils** : 🟠 70 % · 🔴 90 % (une alerte Prometheus part au-delà de 90 % de CPU pendant 5 min, ou sous 10 % de RAM ou de disque libre).""",
     h=3)

table("État des serveurs", "Une ligne par serveur : disponibilité, charge actuelle et durée depuis le dernier démarrage. "
      "Données instantanées (dernière mesure).",
      [prom('up{job=~"node|linux", ' + SRV + '}', instant=True, fmt="table", ref="A"),
       prom('100 - avg by (host) (rate(node_cpu_seconds_total{mode="idle", ' + SRV + '}[5m])) * 100', instant=True,
            fmt="table", ref="B"),
       prom('100 * (1 - node_memory_MemAvailable_bytes{' + SRV + '} / node_memory_MemTotal_bytes{' + SRV + '})',
            instant=True, fmt="table", ref="C"),
       prom('100 * (1 - node_filesystem_avail_bytes{mountpoint="/", ' + SRV + '} / node_filesystem_size_bytes{mountpoint="/", ' + SRV + '})',
            instant=True, fmt="table", ref="D"),
       prom('time() - node_boot_time_seconds{' + SRV + '}', instant=True, fmt="table", ref="E")],
      w=24, h=6,
      transformations=[{"id": "joinByField", "options": {"byField": "host", "mode": "outer"}},
                       {"id": "organize", "options": {
                           "excludeByName": {"Time": True, "Time 1": True, "Time 2": True, "Time 3": True,
                                             "Time 4": True, "Time 5": True, "__name__": True, "instance 1": True,
                                             "instance 2": True, "instance 3": True, "instance 4": True,
                                             "job 1": True, "job 2": True, "job 3": True, "job 4": True,
                                             "role 1": True, "role 2": True, "role 3": True, "role 4": True,
                                             "role": True, "device": True, "fstype": True, "mountpoint": True,
                                             "instance": True, "job": True},
                           "renameByName": {"host": "Serveur", "instance 0": "Adresse", "role 0": "Rôle",
                                            "Value #A": "État", "Value #B": "CPU", "Value #C": "RAM",
                                            "Value #D": "Disque /", "Value #E": "Démarré depuis"},
                           "indexByName": {"host": 0, "Value #A": 1, "Value #B": 2, "Value #C": 3, "Value #D": 4,
                                           "Value #E": 5}}}],
      overrides=[col("État", [{"id": "mappings", "value": [
                     {"type": "value", "options": {"0": {"text": "🔴 HORS LIGNE", "color": "red"},
                                                   "1": {"text": "🟢 EN LIGNE", "color": "green"}}}]},
                              {"id": "custom.cellOptions", "value": {"type": "color-text"}}]),
                 col("CPU", gauge_cell("percent", TH_RES)),
                 col("RAM", gauge_cell("percent", TH_RES)),
                 col("Disque /", gauge_cell("percent", TH_RES)),
                 col("Démarré depuis", [{"id": "unit", "value": "dtdurations"}, {"id": "decimals", "value": 0}])])

ts("Utilisation CPU (%)", "Part du temps où les processeurs travaillent. Des pics courts sont normaux "
   "(mise à jour, analyse antivirus). Un plateau au-dessus de 90 % déclenche l'alerte CPUEleve.",
   [prom('100 - avg by (host) (rate(node_cpu_seconds_total{mode="idle", ' + SRV + '}[$__rate_interval])) * 100',
         "{{host}}")], w=8, unit="percent", maxv=100, th=TH_RES, th_style="dashed",
   legend_calcs=["mean", "max", "lastNotNull"])
ts("Mémoire utilisée (%)", "RAM réellement occupée (hors cache). Wazuh (indexeur Java) est le plus gourmand. "
   "Au-delà de 90 %, le système commence à tuer des processus.",
   [prom('100 * (1 - node_memory_MemAvailable_bytes{' + SRV + '} / node_memory_MemTotal_bytes{' + SRV + '})',
         "{{host}}")], w=8, unit="percent", maxv=100, th=TH_RES, th_style="dashed",
   legend_calcs=["mean", "max", "lastNotNull"])
ts("Disque / utilisé (%)", "Remplissage de la partition système. Les journaux et l'index Wazuh grossissent "
   "chaque jour : la pente de la courbe permet d'anticiper la saturation.",
   [prom('100 * (1 - node_filesystem_avail_bytes{mountpoint="/", ' + SRV + '} / node_filesystem_size_bytes{mountpoint="/", ' + SRV + '})',
         "{{host}}")], w=8, unit="percent", maxv=100, th=TH_RES, th_style="dashed",
   legend_calcs=["lastNotNull"])
ts("Trafic réseau reçu", "Débit entrant par serveur (toutes cartes sauf loopback). Un pic inhabituel peut "
   "signaler un transfert massif ou une attaque.",
   [prom('sum by (host) (rate(node_network_receive_bytes_total{device!~"lo|veth.*|docker.*", ' + SRV + '}[$__rate_interval])) * 8',
         "{{host}}")], w=12, unit="bps", legend_calcs=["mean", "max"])
ts("Charge système (load 1 min)", "Nombre moyen de tâches en attente du processeur. À comparer au nombre de "
   "cœurs : au-delà, le serveur est saturé.",
   [prom('node_load1{' + SRV + '}', "{{host}}")], w=12, legend_calcs=["mean", "max"])

# =====================================================================================================
row("🦠 Antivirus ClamAV – SRV-SUPERVISION")
text("""**À quoi ça sert ?** Bloquer les fichiers malveillants (pièces jointes, téléchargements).
Trois mécanismes : **clamd** (moteur), **clamonacc** (analyse en temps réel du dossier Téléchargements), **scan hebdomadaire** (tout le disque, dimanche 2 h).
**freshclam** met à jour les signatures plusieurs fois par jour : une base de plus de 48 h déclenche une alerte.
🧪 *Test* : déposer le fichier de test **EICAR** (inoffensif) → il apparaît ci-dessous dans « Détections ».""", h=3)

stat("clamd", "Le démon d'analyse répond-il ? (métrique clamav_up, mise à jour toutes les 5 min par cron).",
     [prom('clamav_up', instant=True)], w=3, mappings=onoff(), th=thr("red", (1, "green")))
stat("clamonacc", "Le processus de protection à l'accès tourne-t-il ?",
     [prom('clamav_onaccess_up', instant=True)], w=3, mappings=onoff(), th=thr("red", (1, "green")))
stat("freshclam", "Le service de mise à jour des signatures est-il actif ?",
     [prom('clamav_freshclam_up', instant=True)], w=3, mappings=onoff(), th=thr("red", (1, "green")))
stat("Âge base", "Temps écoulé depuis la dernière mise à jour de la base « daily ». "
     "🟢 < 24 h · 🟠 24-48 h · 🔴 > 48 h (alerte SignaturesClamAVObsoletes).",
     [prom('time() - clamav_db_updated_timestamp_seconds', instant=True)], w=3, unit="dtdurations",
     th=thr("green", (86400, "orange"), (172800, "red")), decimals=0)
stat("Signatures", "Nombre total de signatures de virus chargées (main + daily + bytecode).",
     [prom('clamav_signatures_total', instant=True)], w=3, unit="short", th=thr("blue"), decimals=2)
stat("Version", "Numéro de version de la base daily : il augmente à chaque mise à jour.",
     [prom('clamav_db_version', instant=True)], w=3, th=thr("purple"), unit="none")
stat("Scan hebdo", "Date de fin de la dernière analyse complète planifiée (cron, dimanche 2 h).",
     [prom('clamav_scan_last_end_timestamp_seconds * 1000', instant=True)], w=3, unit="dateTimeFromNow",
     th=thr("text"), color_mode="none")
stat("Infectés", "Fichiers infectés trouvés lors de la dernière analyse hebdomadaire "
     "(sur le nombre de fichiers analysés, visible au survol).",
     [prom('clamav_scan_last_infected', instant=True)], w=3, th=thr("green", (1, "red")))

ts("Détections de virus dans le temps", "Chaque barre = fichiers détectés comme infectés, par mécanisme "
   "(clamd = analyse à la demande, clamonacc = temps réel, scan-hebdo = analyse planifiée). Source : journaux ClamAV via Loki.",
   [loki('sum by (log) (count_over_time({job="clamav"} |= "FOUND" [$__auto]))', "{{log}}")], w=12, h=8,
   bars=True, stack=True)
ts("Mises à jour des signatures", "Nombre de bases téléchargées par freshclam. Des barres régulières = "
   "mises à jour fonctionnelles. 🟠 « Moteur à mettre à jour » : freshclam signale qu'une version plus récente "
   "du logiciel ClamAV existe (les signatures, elles, sont à jour). 🔴 Erreurs : échec de téléchargement.",
   [loki('sum(count_over_time({job="clamav", log="freshclam"} |~ "updated \\\\(version" [$__auto]))', "Base mise à jour"),
    loki('sum(count_over_time({job="clamav", log="freshclam"} |= "OUTDATED" [$__auto]))', "Moteur à mettre à jour", ref="B"),
    loki('sum(count_over_time({job="clamav", log="freshclam"} |~ "(?i)error|warning" != "OUTDATED" != "Local version" [$__auto]))',
         "Erreurs", ref="C")],
   w=12, h=8, bars=True, stack=True, overrides=[color_override("Base mise à jour", "green"),
                                                color_override("Moteur à mettre à jour", "orange"),
                                                color_override("Erreurs", "red")])
logs("📜 Journal des détections ClamAV", "Lignes « FOUND » des journaux ClamAV : chemin du fichier et nom de la menace.",
     [loki('{job="clamav"} |= "FOUND"')], h=7)

# =====================================================================================================
row("🔐 Sécurité – Wazuh (SIEM)")
text("""**À quoi ça sert ?** Wazuh lit les journaux de **SRV-AD**, **SRV-GLPI** et **SRV-WAZUH**, les compare à des milliers de règles et lève des **alertes notées de 0 à 15**.
| Niveau | Gravité | Exemples |
|---|---|---|
| 3 – 6 | 🔵 faible | connexion réussie, paquet installé |
| 7 – 11 | 🟠 moyenne | fichier surveillé modifié, contrôle CIS échoué, compte AD créé |
| 12 – 15 | 🔴 critique | force brute suivie d'un succès, donnée sensible RedOne modifiée |
Les règles **1001xx** sont propres à RedOne (données sensibles, comptes AD).""", h=6)

ts("Alertes par niveau de gravité", "Volume d'alertes Wazuh dans le temps, empilé par gravité. "
   "Une barre rouge = un événement critique à investiguer.",
   [loki('sum(count_over_time({' + WZ + ', level=~"[3-6]"}[$__auto]))', "Faible (3-6)"),
    loki('sum(count_over_time({' + WZ + ', level=~"' + LV_MOY + '"}[$__auto]))', "Moyenne (7-11)", ref="B"),
    loki('sum(count_over_time({' + WZ + ', level=~"' + LV_CRIT + '"}[$__auto]))', "Critique (12+)", ref="C")],
   w=16, h=8, bars=True, stack=True,
   overrides=[color_override("Faible (3-6)", "#5794F2"), color_override("Moyenne (7-11)", "orange"),
              color_override("Critique (12+)", "red")])
pie("Alertes par machine", "Répartition des alertes de la période entre les machines surveillées (agents Wazuh).",
    [loki('sum by (agent) (count_over_time({' + WZ + '}[$__range]))', "{{agent}}", instant=True)], w=8, h=8)

gauge_targets = [loki('max by (agent) (last_over_time({' + WZ + '} |= `"type":"summary"` ' + RULE + '| id=~"1900[345]" | regexp `"score":"(?P<score>\\d+)"` | unwrap score [7d]))', "{{agent}}", instant=True)]
bargauge("Conformité CIS (score SCA)", "Score de durcissement mesuré par Wazuh (Security Configuration Assessment) "
         "par rapport au référentiel CIS. 🔴 < 40 % · 🟠 40-60 % · 🟢 > 60 %. Il progresse quand on applique "
         "les recommandations (script cis-harden.sh).",
         gauge_targets, w=8, h=8, unit="percent", maxv=100, th=thr("red", (40, "orange"), (60, "green")),
         mode="gradient")
bargauge("Tactiques MITRE ATT&CK observées", "Classement des alertes selon la matrice MITRE ATT&CK "
         "(étape d'une attaque : accès initial, persistance, élévation de privilèges…).",
         [loki('topk(8, sum by (tactic) (count_over_time({' + WZ + '} | regexp `"tactic":\\["(?P<tactic>[^"]+)"` '
               '| tactic!="" [$__range])))', "{{tactic}}", instant=True)],
         w=8, h=8, th=thr("#8F3BB8"), mode="gradient", color="continuous-purples")
bargauge("Échecs d'authentification par compte", "Comptes visés par des connexions refusées. "
         "Un compte inconnu (ex. « admin », « test ») = tentative d'intrusion.",
         [loki('topk(8, sum by (compte) (count_over_time({' + WZ + '} |~ "authentication_fail" '
               '| regexp `"(?:dstuser|srcuser|targetUserName)":"(?P<compte>[^"]+)"` | compte!="" [$__range])))', "{{compte}}",
               instant=True)],
         w=8, h=8, th=thr("orange", (10, "red")))

table("Top 10 des règles déclenchées", "Les règles Wazuh qui ont produit le plus d'alertes sur la période (hors contrôles CIS individuels, résumés dans le panneau Conformité CIS). "
      "Utile pour repérer le « bruit » (à ajuster) et les vrais problèmes.",
      [loki('topk(10, sum by (id, niveau, description) (count_over_time({' + WZ + '} ' + RULE + '| id!~"1900[6-9]" [$__range])))', instant=True)],
      w=14, h=9,
      transformations=[{"id": "organize", "options": {
          "excludeByName": {"Time": True},
          "renameByName": {"id": "Règle", "niveau": "Niveau", "description": "Description", "Value #A": "Alertes",
                           "Value": "Alertes"},
          "indexByName": {"id": 0, "niveau": 1, "description": 2, "Value #A": 3}}},
          {"id": "convertFieldType", "options": {"conversions": [{"targetField": "Niveau", "destinationType": "number"}]}},
          {"id": "sortBy", "options": {"sort": [{"field": "Alertes", "desc": True}]}}],
      overrides=[col("Niveau", [{"id": "custom.cellOptions", "value": {"type": "color-background"}},
                                {"id": "thresholds", "value": thr("#5794F2", (7, "orange"), (12, "red"))},
                                {"id": "custom.width", "value": 80}]),
                 col("Règle", [{"id": "custom.width", "value": 80}]),
                 col("Alertes", [{"id": "custom.cellOptions", "value": {"type": "gauge", "mode": "basic"}},
                                 {"id": "color", "value": {"mode": "continuous-BlPu"}},
                                 {"id": "custom.width", "value": 220}])])
table("Règles RedOne et intégrité des fichiers", "Alertes des règles personnalisées RedOne (1001xx) "
      "et du contrôle d'intégrité (FIM : fichier ajouté, modifié, supprimé).",
      [loki('sum by (agent, id, description) (count_over_time({' + WZ + '} ' + RULE + '| id=~"1001[0-9]{2}|55[0-4]" [$__range]))', instant=True)],
      w=10, h=9,
      transformations=[{"id": "organize", "options": {
          "excludeByName": {"Time": True},
          "renameByName": {"agent": "Machine", "id": "Règle", "description": "Description", "Value #A": "Nb",
                           "Value": "Nb"},
          "indexByName": {"agent": 0, "id": 1, "description": 2, "Value #A": 3}}},
          {"id": "sortBy", "options": {"sort": [{"field": "Nb", "desc": True}]}}],
      overrides=[col("Règle", [{"id": "custom.width", "value": 70}]), col("Machine", [{"id": "custom.width", "value": 110}]),
                 col("Nb", [{"id": "custom.width", "value": 60}])],
      no_value="Aucune alerte RedOne / FIM sur la période ✅")

logs("🚨 Dernières alertes Wazuh de niveau ≥ 7", "Fil des alertes moyennes et critiques, la plus récente en haut. "
     "Cliquer sur une ligne affiche le détail complet (JSON Wazuh : MITRE, conformité RGPD/PCI, journal d'origine).",
     [loki('{' + WZ + ', level=~"' + LV_MOY + '|' + LV_CRIT + '"} ' + RULE + '| line_format "[{{.agent}}] niveau {{.niveau}} · règle {{.id}} · {{.description}}"')], h=10)

# =====================================================================================================
row("📣 Alertes Prometheus & mode d'emploi")
table("Alertes Prometheus déclenchées", "Règles Prometheus en état « firing » (fichier redone-alerts.yml). "
      "Vide = tout va bien.",
      [prom('ALERTS{alertstate="firing"}', instant=True, fmt="table")], w=12, h=7,
      transformations=[{"id": "organize", "options": {
          "excludeByName": {"Time": True, "__name__": True, "alertstate": True, "Value": True, "monitor": True,
                            "job": True, "role": True},
          "renameByName": {"alertname": "Alerte", "severity": "Gravité", "host": "Serveur", "instance": "Adresse",
                           "mountpoint": "Partition"}}}],
      overrides=[col("Gravité", [{"id": "custom.cellOptions", "value": {"type": "color-background"}},
                                 {"id": "mappings", "value": [{"type": "value", "options": {
                                     "critical": {"text": "CRITIQUE", "color": "red"},
                                     "warning": {"text": "AVERTISSEMENT", "color": "orange"}}}]}])],
      no_value="✅ Aucune alerte active")
text("""### 🧪 Démontrer le dashboard (épreuve E5 / E6)
| Test | Commande | Ce qui bouge ici |
|---|---|---|
| Virus | déposer le fichier **EICAR** dans *Téléchargements* | « Virus détectés », journal ClamAV |
| Force brute | 6 × `ssh faux@10.2.1.50` avec un mauvais mot de passe | « Échecs d'authentification », alerte niveau 10 |
| Intégrité | modifier un fichier de `/srv/redone/donnees-sensibles` | règle **100100** (niveau 12) |
| AD | créer un compte de test dans l'AD | règle **100110** |
| Panne | `systemctl stop prometheus-node-exporter` sur SRV-GLPI | serveur 🔴, alerte *HoteInjoignable* après 3 min |""",
     w=12, h=7, title="Mode d'emploi")

newline()
dash = {
    "uid": "redone-soc",
    "title": "RedOne – Centre de supervision sécurité",
    "description": "Vue unifiée Prometheus + ClamAV + Wazuh pour l'infrastructure RedOne (AP2 BTS SIO SISR)",
    "tags": ["RedOne", "AP2", "sécurité", "wazuh", "clamav", "prometheus"],
    "timezone": "browser",
    "editable": True,
    "graphTooltip": 1,
    "refresh": "30s",
    "time": {"from": "now-12h", "to": "now"},
    "timepicker": {"refresh_intervals": ["30s", "1m", "5m", "15m"]},
    "schemaVersion": 41,
    "version": 1,
    "links": [
        {"title": "Wazuh", "type": "link", "url": "https://192.168.100.209", "targetBlank": True, "icon": "external link"},
        {"title": "GLPI", "type": "link", "url": "https://192.168.100.208", "targetBlank": True, "icon": "external link"},
        {"title": "Autres tableaux", "type": "dashboards", "tags": [], "asDropdown": True, "includeVars": False},
    ],
    "templating": {"list": [
        {"name": "serveur", "label": "Serveur (Prometheus)", "type": "query", "datasource": PROM,
         "query": {"query": 'label_values(up{job=~"node|linux"}, host)', "refId": "PrometheusVariableQueryEditor-VariableQuery",
                   "qryType": 1},
         "definition": 'label_values(up{job=~"node|linux"}, host)', "refresh": 2, "multi": True, "includeAll": True,
         "allValue": ".*", "current": {"text": ["All"], "value": ["$__all"]}, "sort": 1},
        {"name": "agent", "label": "Machine (Wazuh)", "type": "query", "datasource": LOKI,
         "query": {"type": 1, "label": "agent", "stream": '{job="wazuh"}', "refId": "LokiVariableQueryEditor-VariableQuery"},
         "definition": "", "refresh": 2, "multi": True, "includeAll": True, "allValue": ".+",
         "current": {"text": ["All"], "value": ["$__all"]}, "sort": 1},
    ]},
    "annotations": {"list": [
        {"builtIn": 1, "datasource": {"type": "grafana", "uid": "-- Grafana --"}, "enable": True, "hide": True,
         "iconColor": "rgba(0, 211, 255, 1)", "name": "Annotations & Alerts", "type": "dashboard"},
        {"name": "Virus détecté", "datasource": LOKI, "enable": True, "iconColor": "red",
         "expr": '{job="clamav"} |= "FOUND"', "titleFormat": "🦠 ClamAV", "textFormat": "{{__line__}}",
         "instant": False},
        {"name": "Alerte Wazuh critique", "datasource": LOKI, "enable": False, "iconColor": "orange",
         "expr": '{job="wazuh", level=~"' + LV_CRIT + '"} ' + RULE + '| line_format "[{{.agent}}] {{.description}}"',
         "titleFormat": "🔐 Wazuh", "instant": False},
    ]},
    "panels": panels,
}
with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump(dash, f, ensure_ascii=False, indent=2)
print("panneaux :", len(panels))

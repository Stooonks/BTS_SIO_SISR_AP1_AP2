# Génère le dashboard Grafana « RedOne – Zabbix » (source : plugin Zabbix, uid zabbix-redone)
import json, sys

DS = {"type": "alexanderzobnin-zabbix-datasource", "uid": "zabbix-redone"}
panels, pos, nid = [], {"x": 0, "y": 0, "h": 0}, [0]


def place(w, h):
    if pos["x"] + w > 24:
        pos.update(x=0, y=pos["y"] + pos["h"], h=0)
    g = {"x": pos["x"], "y": pos["y"], "w": w, "h": h}
    pos["x"] += w
    pos["h"] = max(pos["h"], h)
    return g


def new_id():
    nid[0] += 1
    return nid[0]


def row(title):
    if pos["x"]:
        pos.update(x=0, y=pos["y"] + pos["h"], h=0)
    panels.append({"id": new_id(), "type": "row", "title": title, "collapsed": False, "panels": [], "gridPos": place(24, 1)})
    pos.update(x=0, y=pos["y"] + 1, h=0)


def q(item, group="/^RedOne/", host="/.*/", ref="A", alias=True):
    t = {"refId": ref, "datasource": DS, "queryType": "0", "group": {"filter": group}, "host": {"filter": host},
         "application": {"filter": ""}, "itemTag": {"filter": ""}, "item": {"filter": item},
         "functions": [], "options": {"showDisabledItems": False, "skipEmptyValues": False,
                                      "disableDataAlignment": False, "useZabbixValueMapping": False}}
    return t


def thr(*steps):
    s = [{"color": steps[0], "value": None}] + [{"color": c, "value": v} for v, c in steps[1:]]
    return {"mode": "absolute", "steps": s}


def text(md, w=24, h=4, title=""):
    panels.append({"id": new_id(), "type": "text", "title": title, "gridPos": place(w, h), "transparent": not title,
                   "options": {"mode": "markdown", "content": md}})


def stat(title, desc, targets, w, h=4, mappings=None, th=None, unit="none"):
    panels.append({"id": new_id(), "type": "stat", "title": title, "description": desc, "gridPos": place(w, h),
                   "datasource": DS, "targets": targets,
                   "fieldConfig": {"defaults": {"unit": unit, "mappings": mappings or [], "thresholds": th or thr("green"),
                                                "color": {"mode": "thresholds"}, "noValue": "pas de donnée", "displayName": "${__field.labels.host}"}, "overrides": []},
                   "options": {"reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": False},
                               "colorMode": "background", "graphMode": "none", "textMode": "value_and_name",
                               "justifyMode": "center", "orientation": "auto", "wideLayout": True}})


def ts(title, desc, targets, w=12, h=8, unit="percent", maxv=100, th=None):
    panels.append({"id": new_id(), "type": "timeseries", "title": title, "description": desc, "gridPos": place(w, h),
                   "datasource": DS, "targets": targets,
                   "fieldConfig": {"defaults": {"unit": unit, "min": 0, "max": maxv, "displayName": "${__field.labels.host}", "color": {"mode": "palette-classic"},
                                                "thresholds": th or thr("green", (70, "orange"), (90, "red")),
                                                "custom": {"lineWidth": 2, "fillOpacity": 12, "gradientMode": "opacity",
                                                           "showPoints": "never", "spanNulls": True,
                                                           "thresholdsStyle": {"mode": "dashed" if maxv == 100 else "off"}}},
                                   "overrides": []},
                   "options": {"legend": {"displayMode": "table", "placement": "right", "calcs": ["mean", "max", "lastNotNull"], "showLegend": True},
                               "tooltip": {"mode": "multi", "sort": "desc"}}})


DISPO = [{"type": "value", "options": {"1": {"text": "DISPONIBLE", "color": "green"},
                                        "2": {"text": "INDISPONIBLE", "color": "red"},
                                        "0": {"text": "AGENT ABSENT", "color": "orange"}}}]
PING = [{"type": "value", "options": {"1": {"text": "RÉPOND", "color": "green"}, "0": {"text": "NE RÉPOND PAS", "color": "red"}}}]

text("""## 📡 RedOne – Supervision Zabbix
**Zabbix** (SRV-ZABBIX, `10.2.1.52`) interroge chaque minute un **agent** installé sur les serveurs et les postes, et teste par **ping** les équipements sans agent (pfSense, TrueNAS).
Il évalue des **déclencheurs** (*triggers*) : quand un seuil est franchi, un **problème** apparaît ci-dessous avec sa gravité.
Ce tableau lit Zabbix via son API (utilisateur `grafana` en **lecture seule**, authentification par jeton).
👉 Survolez **ⓘ** pour le détail de chaque panneau. Interface Zabbix complète : **https://192.168.100.210/zabbix**""", w=16, h=6)
text("""| Gravité Zabbix | Couleur |
|---|---|
| Désastre / Haute | 🔴 |
| Moyenne | 🟠 |
| Avertissement / Information | 🟡 🔵 |

Les agents Windows s'installent avec `\\\\RedOne.local\\NETLOGON\\zabbix-agent.ps1`.""", w=8, h=6, title="Lecture")

row("🚨 Problèmes en cours")
panels.append({"id": new_id(), "type": "alexanderzobnin-zabbix-triggers-panel", "title": "Problèmes Zabbix actifs",
               "description": "Liste des déclencheurs en état PROBLÈME, du plus grave au moins grave : hôte, gravité, durée, description. "
                              "Vide = tout fonctionne.",
               "gridPos": place(24, 9), "datasource": DS,
               "targets": [{"refId": "A", "datasource": DS, "queryType": "5", "group": {"filter": "/^RedOne/"},
                            "host": {"filter": "/.*/"}, "application": {"filter": ""}, "proxy": {"filter": ""},
                            "trigger": {"filter": ""}, "tags": {"filter": ""},
                            "options": {"minSeverity": 0, "acknowledged": 2, "sortProblems": "default", "showProblems": "problems",
                                        "hostsInMaintenance": False, "hostProxy": False, "limit": 100}}],
               "options": {"layout": "table", "pageSize": 10, "showTags": True, "hostField": True, "hostTechNameField": False,
                           "hostGroups": False, "statusField": True, "statusIcon": True, "severityField": True, "ageField": True,
                           "descriptionField": True, "descriptionAtNewLine": False, "ackField": True, "fontSize": "100%",
                           "highlightNewEvents": True, "highlightNewerThan": "1h", "customLastChangeFormat": False,
                           "sortProblems": "priority", "markAckEvents": False}})

row("🟢 Disponibilité")
stat("Agent Zabbix", "État de l'agent sur chaque machine. AGENT ABSENT = l'agent n'est pas encore installé (machines Windows : lancer le script NETLOGON).",
     [q("Zabbix agent availability")], 14, 5, DISPO, thr("orange"))
stat("Ping", "Réponse au ping du serveur Zabbix (modèle ICMP Ping) : utile pour les équipements sans agent comme pfSense et TrueNAS.",
     [q("ICMP ping")], 10, 5, PING, thr("red", (1, "green")))

row("💾 Sauvegardes Veeam (SRV-VEEAM 10.2.1.53 → copie TrueNAS)")
VEEAM = [{"type": "value", "options": {"0": {"text": "SUCCÈS", "color": "green"}, "1": {"text": "AVERTISSEMENT", "color": "orange"},
                                        "2": {"text": "ÉCHEC", "color": "red"}, "3": {"text": "AUCUNE SAUVEGARDE", "color": "dark-red"}}}]
COPIE = [{"type": "value", "options": {"0": {"text": "COPIE OK", "color": "green"}, "1": {"text": "COPIE EN ÉCHEC", "color": "red"},
                                       "2": {"text": "JAMAIS FAITE", "color": "orange"}}}]
SRV = "/^SRV-AD/"
stat("Dernière sauvegarde", "Résultat de la dernière sauvegarde Veeam de chaque contrôleur de domaine (événement 190 du journal « Veeam Agent »), "
     "envoyé à Zabbix toutes les 15 min et à la fin de chaque sauvegarde par C:\\Scripts\\veeam-status.ps1.",
     [q("Veeam : résultat de la dernière sauvegarde", host=SRV)], 8, 5, VEEAM, thr("green"))
stat("Âge de la sauvegarde", "Heures écoulées depuis la dernière sauvegarde. Sauvegarde quotidienne à 0 h 30 : au-delà de 26 h, Zabbix lève une alerte.",
     [q("Veeam : âge de la dernière sauvegarde", host=SRV)], 6, 5, None, thr("green", (26, "red")), unit="h")
stat("Points de restauration", "Nombre de fichiers de sauvegarde (.vbk complète + .vib incrémentales) dans \\\\SRV-VEEAM\\Sauvegardes. Rétention : 14 jours.",
     [q("Veeam : points de restauration", host=SRV)], 5, 5, None, thr("red", (1, "green")))
stat("Volume sauvegardé", "Taille des sauvegardes de chaque serveur sur le dépôt.",
     [q("Veeam : taille des sauvegardes", host=SRV)], 5, 5, None, thr("blue"), unit="decgbytes")
stat("Dépôt S: libre", "Espace libre sur le disque de sauvegarde de SRV-VEEAM (300 Go). Alerte Zabbix sous 15 %.",
     [q("Dépôt Veeam : espace libre en %", host="SRV-VEEAM")], 6, 5, None, thr("red", (15, "orange"), (30, "green")), unit="percent")
stat("Copie TrueNAS", "Résultat de la copie miroir nocturne (4 h) du dépôt vers \\\\truenas.redone.local\\copie-veeam : 2ᵉ copie de la règle 3-2-1.",
     [q("Copie TrueNAS : résultat", host="SRV-VEEAM")], 6, 5, COPIE, thr("green"))
panels.append({"id": new_id(), "type": "logs", "title": "Journal des sauvegardes (Loki)", "gridPos": place(12, 5),
               "description": "Messages envoyés en syslog par les serveurs (Alloy, port UDP 5515, job=\"veeam\").",
               "datasource": {"type": "loki", "uid": "loki-clamav"},
               "targets": [{"refId": "A", "datasource": {"type": "loki", "uid": "loki-clamav"}, "expr": "{job=\"veeam\"}"}],
               "options": {"showTime": True, "wrapLogMessage": True, "sortOrder": "Descending", "enableLogDetails": True}})

row("📊 Ressources (agents Zabbix)")
ts("CPU", "Utilisation processeur relevée par l'agent Zabbix (élément « CPU utilization »). Seuils 70 / 90 %.", [q("CPU utilization")])
ts("Mémoire", "Utilisation de la mémoire vive (élément « Memory utilization »).", [q("Memory utilization")])
ts("Disque /", "Remplissage de la partition système des serveurs Linux (« FS [/]: Space: Used, in % »).", [q("/FS \\[\\/\\]: Space: Used, in %/")])
ts("Temps de réponse ICMP", "Latence du ping depuis SRV-ZABBIX. Une hausse brutale signale une saturation réseau.",
   [q("ICMP response time")], unit="s", maxv=None)

dash = {"uid": "redone-zabbix", "title": "RedOne – Zabbix", "tags": ["RedOne", "AP2", "zabbix"],
        "description": "Problèmes, disponibilité et ressources remontés par Zabbix (SRV-ZABBIX)",
        "timezone": "browser", "refresh": "1m", "time": {"from": "now-6h", "to": "now"}, "schemaVersion": 41,
        "editable": True, "graphTooltip": 1,
        "links": [{"title": "Interface Zabbix", "type": "link", "url": "https://192.168.100.210/zabbix", "targetBlank": True, "icon": "external link"},
                  {"title": "Centre de supervision sécurité", "type": "link", "url": "/d/redone-soc", "icon": "dashboard"}],
        "panels": panels}
with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump(dash, f, ensure_ascii=False, indent=2)
print("panneaux :", len(panels))

# Génère le dashboard Grafana « RedOne – Routeur R-REDONE » (uid redone-routeur)
# Sources : Zabbix (SNMPv3, modèle Cisco IOS) et Loki (alertes Wazuh issues des journaux du routeur)
# Usage : python3 gen_routeur_dashboard.py /var/lib/grafana/dashboards/redone-routeur.json
import json, sys

ZBX = {"type": "alexanderzobnin-zabbix-datasource", "uid": "zabbix-redone"}
LOKI = {"type": "loki", "uid": "loki-clamav"}
HOTE = "/R-REDONE/"          # le plugin filtre sur le nom affiché « R-REDONE (routeur Cisco) »
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


def zq(item, ref="A", texte=False):
    return {"refId": ref, "datasource": ZBX, "queryType": "2" if texte else "0",
            "group": {"filter": "/^RedOne/"}, "host": {"filter": HOTE}, "application": {"filter": ""},
            "itemTag": {"filter": ""}, "item": {"filter": item}, "functions": [],
            "textFilter": "", "useCaptureGroups": False,
            "options": {"showDisabledItems": False, "skipEmptyValues": False, "disableDataAlignment": False,
                        "useZabbixValueMapping": False}}


def lq(expr, ref="A", legend="", instant=False):
    return {"refId": ref, "datasource": LOKI, "expr": expr, "legendFormat": legend,
            "queryType": "instant" if instant else "range"}


def thr(*steps):
    return {"mode": "absolute", "steps": [{"color": steps[0], "value": None}] + [{"color": c, "value": v} for v, c in steps[1:]]}


def stat(title, desc, targets, w, h=4, unit="none", mappings=None, th=None, ds=ZBX, texte=False, decimals=None):
    d = {"unit": unit, "mappings": mappings or [], "thresholds": th or thr("blue"), "color": {"mode": "thresholds"},
         "noValue": "—"}
    if decimals is not None:
        d["decimals"] = decimals
    panels.append({"id": new_id(), "type": "stat", "title": title, "description": desc, "gridPos": place(w, h),
                   "datasource": ds, "targets": targets, "fieldConfig": {"defaults": d, "overrides": []},
                   "options": {"reduceOptions": {"calcs": ["lastNotNull"], "fields": "/^(?!Time$|time$).*/" if texte else "", "values": False},
                               "colorMode": "none" if texte else "background", "graphMode": "none",
                               "textMode": "value", "justifyMode": "center", "wideLayout": True}})


def courbe(title, desc, targets, w=12, h=8, unit="percent", maxv=None, th=None, renommer=None, ds=ZBX):
    p = {"id": new_id(), "type": "timeseries", "title": title, "description": desc, "gridPos": place(w, h),
         "datasource": ds, "targets": targets,
         "fieldConfig": {"defaults": {"unit": unit, "min": 0, "color": {"mode": "palette-classic"},
                                      "thresholds": th or thr("green"),
                                      "custom": {"lineWidth": 2, "fillOpacity": 15, "gradientMode": "opacity",
                                                 "showPoints": "never", "spanNulls": True,
                                                 "thresholdsStyle": {"mode": "dashed" if th else "off"}}},
                         "overrides": []},
         "options": {"legend": {"displayMode": "list", "placement": "bottom", "showLegend": True},
                     "tooltip": {"mode": "multi", "sort": "desc"}}}
    if maxv is not None:
        p["fieldConfig"]["defaults"]["max"] = maxv
    if renommer:
        p["transformations"] = [{"id": "renameByRegex", "options": {"regex": r, "renamePattern": n}} for r, n in renommer]
    panels.append(p)


OUINON = lambda oui, non: [{"type": "value", "options": {"1": {"text": oui, "color": "green"}, "0": {"text": non, "color": "red"}}}]
SNMP = [{"type": "value", "options": {"1": {"text": "SNMPv3 OK", "color": "green"}, "0": {"text": "INCONNU", "color": "orange"},
                                      "2": {"text": "SNMP EN ÉCHEC", "color": "red"}}}]
PORT = [{"type": "value", "options": {"1": {"text": "ACTIF", "color": "green"}, "2": {"text": "COUPÉ", "color": "red"},
                                      "7": {"text": "COUPÉ", "color": "red"}}}]
ROUTEUR = '{job="wazuh"} |= `"location":"192.168.100.212"`'   # alertes dont l'origine est le routeur

# ---------------------------------------------------------------- En-tête
panels.append({"id": new_id(), "type": "text", "title": "", "transparent": True, "gridPos": place(24, 3),
               "options": {"mode": "markdown", "content":
                           "## 🔀 Routeur R-REDONE – Cisco C1111-4P (IOS-XE 16.8) – `192.168.100.212`\n"
                           "**Zabbix** interroge le routeur toutes les minutes en **SNMPv3 chiffré** (disponibilité, ports, processeur, trafic). "
                           "Ses **journaux** partent vers **Wazuh**, qui alerte sur les connexions, les attaques par force brute et les modifications de configuration. "
                           "Survolez **ⓘ** pour le détail de chaque panneau."}})

# ---------------------------------------------------------------- État
row("🟢 État du routeur")
stat("Routeur joignable", "Ping du routeur par SRV-ZABBIX, chaque minute.", [zq("ICMP ping")], 4, 4, mappings=OUINON("EN LIGNE", "HORS LIGNE"), th=thr("red", (1, "green")))
stat("Supervision SNMPv3", "Zabbix arrive-t-il à interroger le routeur en SNMPv3 (authentification SHA, chiffrement AES-128) ?",
     [zq("SNMP agent availability")], 4, 4, mappings=SNMP, th=thr("orange", (1, "green"), (2, "red")))
stat("Port G0/0/0 (administration)", "État du port relié au réseau de la salle. Alerte Zabbix « Link down » s'il tombe.",
     [zq("/Gi0\\/0\\/0.*Operational status/")], 4, 4, mappings=PORT, th=thr("green"))
stat("Allumé depuis", "Temps depuis le dernier démarrage du routeur. Alerte Zabbix si le routeur redémarre.",
     [zq("Uptime (network)")], 4, 4, unit="dtdurations", th=thr("blue"))
stat("Temps de réponse", "Latence du ping SRV-ZABBIX → routeur.", [zq("ICMP response time")], 4, 4, unit="s",
     th=thr("green", (0.05, "orange"), (0.2, "red")))
stat("Perte de paquets", "Pourcentage de pings perdus.", [zq("ICMP loss")], 4, 4, unit="percent", th=thr("green", (1, "orange"), (20, "red")))

# ---------------------------------------------------------------- Identité
stat("Modèle", "Modèle relevé en SNMP.", [zq("Hardware model name", texte=True)], 4, 3, texte=True)
stat("Système", "Version du système relevée en SNMP.", [zq("Operating system", texte=True)], 4, 3, texte=True)
stat("Numéro de série", "Numéro de série du châssis (inventaire, garantie).", [zq("Hardware serial number", texte=True)], 4, 3, texte=True)
stat("Nom", "Nom du routeur (hostname).", [zq("System name", texte=True)], 4, 3, texte=True)
stat("Emplacement", "Emplacement déclaré (snmp-server location).", [zq("System location", texte=True)], 8, 3, texte=True)

# ---------------------------------------------------------------- Performances
row("📊 Performances")
stat("Processeur", "Charge actuelle du processeur. Alerte Zabbix au-delà de 90 %.", [zq("/CPU utilization/")], 4, 7,
     unit="percent", th=thr("green", (70, "orange"), (90, "red")))
courbe("Processeur dans le temps", "Charge du processeur (SNMP, CISCO-PROCESS-MIB).", [zq("/CPU utilization/")], 8, 7,
       maxv=100, th=thr("green", (70, "orange"), (90, "red")), renommer=[(".*CPU utilization.*", "Processeur")])
stat("Mémoire", "Mémoire utilisée par le processeur. Alerte Zabbix au-delà de 90 %.", [zq("Processor: Memory utilization")], 4, 7,
     unit="percent", th=thr("green", (70, "orange"), (90, "red")))
courbe("Mémoire dans le temps", "Mémoire utilisée (SNMP, CISCO-MEMORY-POOL-MIB).", [zq("Processor: Memory utilization")], 8, 7,
       maxv=100, th=thr("green", (70, "orange"), (90, "red")), renommer=[(".*Memory utilization.*", "Mémoire")])

# ---------------------------------------------------------------- Réseau
row("🌐 Réseau – port G0/0/0")
courbe("Trafic", "Débit entrant (reçu) et sortant (envoyé) du port d'administration.",
       [zq("/Gi0\\/0\\/0.*Bits (received|sent)/")], 12, 8, unit="bps",
       renommer=[(".*Bits received.*", "Reçu"), (".*Bits sent.*", "Envoyé")])
courbe("Temps de réponse", "Latence du ping SRV-ZABBIX → routeur.", [zq("ICMP response time")], 6, 8, unit="s",
       renommer=[(".*", "Latence")])
courbe("Erreurs et paquets rejetés", "Paquets en erreur ou rejetés sur G0/0/0 (câble, duplex, saturation). Doit rester à 0.",
       [zq("/Gi0\\/0\\/0.*(with errors|discarded)/")], 6, 8, unit="pps",
       renommer=[(".*Inbound packets with errors.*", "Erreurs reçues"), (".*Outbound packets with errors.*", "Erreurs envoyées"),
                 (".*Inbound packets discarded.*", "Rejetés en entrée"), (".*Outbound packets discarded.*", "Rejetés en sortie")])

# ---------------------------------------------------------------- Sécurité
row("🛡️ Sécurité (alertes Wazuh issues des journaux du routeur)")
stat("Connexions réussies (24 h)", "Connexions au routeur (SSH ou console) – règle Wazuh 4722.",
     [lq('sum(count_over_time(' + ROUTEUR + ' |= "Successful login to the router" [24h])) or vector(0)', instant=True)],
     6, 4, ds=LOKI, th=thr("blue"))
stat("Échecs de connexion (24 h)", "Mauvais mot de passe ou compte inconnu – règle Wazuh 4724 (niveau 9).",
     [lq('sum(count_over_time(' + ROUTEUR + ' |= "Failed login to the router" [24h])) or vector(0)', instant=True)],
     6, 4, ds=LOKI, th=thr("green", (1, "orange"), (3, "red")))
stat("Attaques bloquées (24 h)", "Déclenchements du blocage après 3 échecs en 60 s (login block-for) – règle RedOne 100120 (niveau 12).",
     [lq('sum(count_over_time(' + ROUTEUR + ' |= "attaque par force brute" [24h])) or vector(0)', instant=True)],
     6, 4, ds=LOKI, th=thr("green", (1, "red")))
stat("Modifications de configuration (24 h)", "Chaque « configure terminal » terminé – règle RedOne 100122, avec le compte qui l'a fait.",
     [lq('sum(count_over_time(' + ROUTEUR + ' |= "configuration du routeur" [24h])) or vector(0)', instant=True)],
     6, 4, ds=LOKI, th=thr("blue"))
courbe("Tentatives de connexion dans le temps", "Échecs et réussites de connexion au routeur.",
       [lq('sum(count_over_time(' + ROUTEUR + ' |= "Failed login to the router" [$__auto])) or vector(0)', "A", "Échecs"),
        lq('sum(count_over_time(' + ROUTEUR + ' |= "Successful login to the router" [$__auto])) or vector(0)', "B", "Réussites")],
       10, 8, unit="short", ds=LOKI)
panels[-1]["fieldConfig"]["overrides"] = [
    {"matcher": {"id": "byName", "options": "Échecs"}, "properties": [{"id": "color", "value": {"mode": "fixed", "fixedColor": "red"}}]},
    {"matcher": {"id": "byName", "options": "Réussites"}, "properties": [{"id": "color", "value": {"mode": "fixed", "fixedColor": "green"}}]}]
panels[-1]["fieldConfig"]["defaults"]["custom"].update({"drawStyle": "bars", "fillOpacity": 70})
panels.append({"id": new_id(), "type": "logs", "title": "Journal de sécurité du routeur", "gridPos": place(14, 8),
               "description": "Alertes Wazuh du routeur, la plus récente en haut.", "datasource": LOKI,
               "targets": [lq(ROUTEUR + ' | regexp "\\"description\\":\\"(?P<alerte>[^\\"]+)\\"" | line_format "niveau {{.level}} – {{.alerte}}"')],
               "fieldConfig": {"defaults": {"noValue": "Aucune alerte sur la période"}, "overrides": []},
               "options": {"showTime": True, "wrapLogMessage": True, "sortOrder": "Descending", "enableLogDetails": True}})

# ---------------------------------------------------------------- Problèmes Zabbix
row("📶 Réseau Visiteurs (10.2.3.0/24, port routé G0/0/1)")
panels.append({"id": new_id(), "type": "text", "title": "Règle appliquée", "gridPos": place(6, 7),
               "options": {"mode": "markdown", "content":
                           "Cahier des charges RedOne : *« Visiteurs : DNS, DHCP et Internet uniquement »*.\n\n"
                           "- **DHCP** : le routeur distribue `10.2.3.20` à `.254`\n- **DNS** : AD `10.2.1.10` autorisé\n"
                           "- **Internet** : par NAT\n- **Réseau RedOne** : 🚫 bloqué par l'ACL `VISITEURS-IN`, chaque tentative est envoyée à Wazuh"}})
stat("Tentatives bloquées (24 h)", "Paquets d'un visiteur vers le réseau interne refusés par l'ACL VISITEURS-IN (règle Wazuh 100123).",
     [lq('sum(count_over_time(' + ROUTEUR + ' |= "VISITEURS-IN" [24h])) or vector(0)', instant=True)],
     5, 7, ds=LOKI, th=thr("green", (1, "orange"), (10, "red")))
courbe("Trafic des visiteurs", "Débit du port G0/0/1 (passerelle des visiteurs) relevé en SNMP.",
       [zq(r"/Gi0\/0\/1.*Bits (received|sent)/")], 13, 7, unit="bps",
       renommer=[(".*Bits received.*", "Reçu des visiteurs"), (".*Bits sent.*", "Envoyé aux visiteurs")])

# Appareils visiteurs : extraits des journaux NAT et ACL du routeur (Loki, job="routeur", conservés 1 an)
RT = '{job="routeur"}'
IPV = r'(?P<ip>10\.2\.[34]\.\d+)'
def lt(expr, ref):
    return {"refId": ref, "datasource": LOKI, "expr": expr, "queryType": "instant", "legendFormat": ""}
panels.append({"id": new_id(), "type": "table", "title": "Appareils visiteurs (IP attribuée par le routeur)",
               "description": "Chaque adresse IP de visiteur vue sur la période : nombre de connexions vers Internet (journal NAT), "
                              "connexions dans les 15 dernières minutes, et tentatives bloquées vers le réseau interne (ACL VISITEURS-IN). "
                              "Prises du switch : 10.2.4.x ; port G0/0/1 : 10.2.3.x.",
               "gridPos": place(12, 8), "datasource": LOKI,
               "targets": [lt('sum by (ip) (count_over_time(' + RT + ' |= "Created Translation" | regexp `Translation \\w+ ' + IPV + ':` [$__range]))', "A"),
                           lt('sum by (ip) (count_over_time(' + RT + ' |= "Created Translation" | regexp `Translation \\w+ ' + IPV + ':` [15m]))', "B"),
                           lt('sum by (ip) (count_over_time(' + RT + ' |= "VISITEURS-IN denied" | regexp `denied \\w+ ' + IPV + '\\(` [$__range]))', "C")],
               "transformations": [{"id": "merge", "options": {}},
                                   {"id": "organize", "options": {"excludeByName": {"Time": True},
                                    "renameByName": {"ip": "Adresse IP", "Value #A": "Connexions (période)",
                                                     "Value #B": "Connexions (15 min)", "Value #C": "Tentatives bloquées"}}}],
               "fieldConfig": {"defaults": {"noValue": "0", "custom": {"align": "center"}},
                               "overrides": [{"matcher": {"id": "byName", "options": "Tentatives bloquées"},
                                              "properties": [{"id": "custom.cellOptions", "value": {"type": "color-background"}},
                                                             {"id": "thresholds", "value": thr("transparent", (1, "orange"), (10, "red"))}]},
                                             {"matcher": {"id": "byName", "options": "Connexions (15 min)"},
                                              "properties": [{"id": "custom.cellOptions", "value": {"type": "color-background"}},
                                                             {"id": "thresholds", "value": thr("transparent", (1, "green"))}]}]},
               "options": {"showHeader": True, "sortBy": [{"displayName": "Connexions (période)", "desc": True}]}})
panels.append({"id": new_id(), "type": "logs", "title": "Journal des connexions des visiteurs (conservé 1 an)",
               "description": "Qui (IP du visiteur) s'est connecté à quoi (destination, port) et quand. Obligation de conservation des données "
                              "de connexion pour un accès Internet ouvert au public (CPCE art. L34-1).",
               "gridPos": place(12, 8), "datasource": LOKI,
               "targets": [{"refId": "A", "datasource": LOKI, "queryType": "range",
                            "expr": RT + ' |= "Created Translation" | regexp `Translation (?P<proto>\\w+) ' + IPV +
                                    r':\d+ \S+ (?P<dest>[\d.]+):(?P<port>\d+)` | line_format "{{.ip}} → {{.dest}}:{{.port}} ({{.proto}})"'}],
               "options": {"showTime": True, "wrapLogMessage": False, "sortOrder": "Descending", "enableLogDetails": False}})

row("💾 Sauvegarde de la configuration (SRV-VEEAM → dépôt S:\\Sauvegardes → TrueNAS)")
SAUV = [{"type": "value", "options": {"0": {"text": "SUCCÈS", "color": "green"}, "1": {"text": "ÉCHEC", "color": "red"}}}]
stat("Dernière sauvegarde", "Résultat de la dernière récupération de la configuration par SRV-VEEAM (SSH par clé, toutes les 4 h et à 3 h 30).",
     [zq("Sauvegarde config : résultat")], 6, 4, mappings=SAUV, th=thr("green"))
p = zq("Sauvegarde config : dernière exécution")
p["functions"] = [{"def": {"name": "scale", "category": "Transform", "params": [{"name": "factor", "type": "float"}]}, "params": ["1000"]}]
stat("Exécutée", "Heure de la dernière exécution. Alerte Zabbix si plus de 26 h sans sauvegarde.", [p], 6, 4,
     unit="dateTimeFromNow", th=thr("blue"))
stat("Versions conservées", "Nombre de versions de la configuration gardées (une nouvelle version seulement quand la configuration change, 90 jours).",
     [zq("Sauvegarde config : versions conservées")], 6, 4, th=thr("blue"))
panels.append({"id": new_id(), "type": "text", "title": "Où sont les sauvegardes ?", "gridPos": place(6, 4),
               "options": {"mode": "markdown", "content": "`S:\\Sauvegardes\\Routeur-R-REDONE` sur **SRV-VEEAM**, "
                           "copié chaque nuit sur le **TrueNAS** (dataset chiffré)."}})

row("🚨 Problèmes Zabbix du routeur")
panels.append({"id": new_id(), "type": "alexanderzobnin-zabbix-triggers-panel", "title": "Problèmes en cours sur R-REDONE",
               "description": "Déclencheurs du modèle Cisco IOS en état PROBLÈME (routeur injoignable, Link down, processeur, mémoire, redémarrage…). Vide = tout va bien.",
               "gridPos": place(24, 6), "datasource": ZBX,
               "targets": [{"refId": "A", "datasource": ZBX, "queryType": "5", "group": {"filter": "/^RedOne/"},
                            "host": {"filter": HOTE}, "application": {"filter": ""}, "proxy": {"filter": ""},
                            "trigger": {"filter": ""}, "tags": {"filter": ""},
                            "options": {"minSeverity": 0, "acknowledged": 2, "sortProblems": "default", "showProblems": "problems",
                                        "hostsInMaintenance": False, "hostProxy": False, "limit": 50}}],
               "options": {"layout": "table", "pageSize": 10, "showTags": False, "hostField": True, "statusField": True,
                           "statusIcon": True, "severityField": True, "ageField": True, "descriptionField": True,
                           "ackField": False, "fontSize": "100%", "sortProblems": "priority"}})

dash = {"uid": "redone-routeur", "title": "RedOne – Routeur R-REDONE", "tags": ["RedOne", "AP2", "routeur", "cisco"],
        "description": "Routeur Cisco R-REDONE : état, performances, trafic, sécurité (Zabbix SNMPv3 + Wazuh)",
        "timezone": "browser", "refresh": "1m", "time": {"from": "now-6h", "to": "now"}, "schemaVersion": 41,
        "editable": True, "graphTooltip": 1,
        "links": [{"title": "RedOne – Zabbix", "type": "link", "url": "/d/redone-zabbix", "icon": "dashboard"},
                  {"title": "Centre de supervision sécurité", "type": "link", "url": "/d/redone-soc", "icon": "dashboard"},
                  {"title": "Interface Zabbix", "type": "link", "url": "https://192.168.100.210/zabbix", "targetBlank": True, "icon": "external link"}],
        "panels": panels}
with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump(dash, f, ensure_ascii=False, indent=2)
print("panneaux :", len(panels))

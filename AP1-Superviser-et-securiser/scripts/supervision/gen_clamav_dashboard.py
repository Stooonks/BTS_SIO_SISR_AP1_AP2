# Génère le dashboard Grafana « ClamAV » (uid clamav-overview) : antivirus de SRV-SUPERVISION
# Usage : python3 gen_clamav_dashboard.py /var/lib/grafana/dashboards/clamav.json
import json, sys

PROM = {"type": "prometheus", "uid": "prometheus-clamav"}
LOKI = {"type": "loki", "uid": "loki-clamav"}
panels, pos = [], {"x": 0, "y": 0, "h": 0}


def place(w, h):
    if pos["x"] + w > 24:
        pos.update(x=0, y=pos["y"] + pos["h"], h=0)
    g = {"x": pos["x"], "y": pos["y"], "w": w, "h": h}
    pos["x"] += w
    pos["h"] = max(pos["h"], h)
    return g


def thr(*steps):
    return {"mode": "absolute", "steps": [{"color": steps[0], "value": None}] + [{"color": c, "value": v} for v, c in steps[1:]]}


def prom(expr):
    return {"refId": "A", "datasource": PROM, "expr": expr, "instant": True}


def loki(expr, legend="", ref="A", instant=False):
    t = {"refId": ref, "datasource": LOKI, "expr": expr, "legendFormat": legend}
    t["queryType"] = "instant" if instant else "range"
    return t


def stat(title, desc, target, w, th, unit="none", mappings=None, decimals=None, ds=PROM):
    d = {"unit": unit, "thresholds": th, "mappings": mappings or [], "color": {"mode": "thresholds"}, "noValue": "0"}
    if decimals is not None:
        d["decimals"] = decimals
    panels.append({"id": len(panels) + 1, "type": "stat", "title": title, "description": desc, "gridPos": place(w, 5),
                   "datasource": ds, "targets": [target], "fieldConfig": {"defaults": d, "overrides": []},
                   "options": {"reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": False},
                               "colorMode": "background", "graphMode": "none", "textMode": "value", "justifyMode": "center"}})


def logs(title, desc, expr, w, h, novalue):
    panels.append({"id": len(panels) + 1, "type": "logs", "title": title, "description": desc, "gridPos": place(w, h),
                   "datasource": LOKI, "targets": [loki(expr)],
                   "fieldConfig": {"defaults": {"noValue": novalue}, "overrides": []},
                   "options": {"showTime": True, "wrapLogMessage": True, "sortOrder": "Descending", "enableLogDetails": True}})


ONOFF = lambda on, off: [{"type": "value", "options": {"1": {"text": on, "color": "green"}, "0": {"text": off, "color": "red"}}}]

panels.append({"id": 100, "type": "text", "title": "", "transparent": True, "gridPos": place(24, 3),
               "options": {"mode": "markdown", "content":
                           "## 🦠 ClamAV – antivirus de SRV-SUPERVISION\n"
                           "**clamd** analyse les fichiers, **clamonacc** les contrôle en temps réel à chaque ouverture (fichier infecté déplacé en quarantaine `/var/quarantine`), "
                           "**freshclam** met à jour les signatures. Une analyse complète a lieu chaque semaine. Survolez **ⓘ** pour le détail de chaque panneau."}})

stat("Moteur clamd", "Le démon d'analyse répond-il ? (clamav_up, relevé toutes les 5 min)", prom("clamav_up"), 4,
     thr("red", (1, "green")), mappings=ONOFF("EN LIGNE", "HORS LIGNE"))
stat("Temps réel", "Protection à l'accès clamonacc : chaque fichier ouvert est analysé.", prom("clamav_onaccess_up"), 4,
     thr("red", (1, "green")), mappings=ONOFF("ACTIVE", "ARRÊTÉE"))
stat("Mises à jour", "Service freshclam (vérifie les nouvelles signatures plusieurs fois par jour).", prom("clamav_freshclam_up"), 4,
     thr("red", (1, "green")), mappings=ONOFF("ACTIVES", "ARRÊTÉES"))
stat("Signatures chargées", "Nombre de signatures de virus connues (bases main, daily et bytecode).", prom("clamav_signatures_total"), 4,
     thr("red", (1000000, "green")), unit="short", decimals=2)
stat("Version de la base", "Numéro de la base daily publiée par ClamAV (augmente chaque jour).", prom("clamav_db_version"), 4,
     thr("blue"), unit="none")
stat("Âge de la base", "Ancienneté de la base daily. freshclam vérifie plusieurs fois par jour ; ClamAV publie en général une base par jour, parfois moins : orange au-delà de 3 jours, rouge au-delà de 5.",
     prom("time() - clamav_db_updated_timestamp_seconds"), 4, thr("green", (259200, "orange"), (432000, "red")), unit="dtdurations")

stat("Détections (24 h)", "Fichiers infectés trouvés sur les dernières 24 h (clamd et clamonacc).",
     loki('sum(count_over_time({job="clamav"} |= "FOUND" [24h])) or vector(0)', instant=True), 6,
     thr("green", (1, "red")), ds=LOKI)
stat("Dernière analyse complète", "Fin de la dernière analyse hebdomadaire de tout le serveur.",
     prom("clamav_scan_last_end_timestamp_seconds * 1000"), 6, thr("blue"), unit="dateTimeFromNow")
stat("Fichiers analysés", "Nombre de fichiers contrôlés lors de la dernière analyse hebdomadaire.",
     prom("clamav_scan_last_files"), 6, thr("blue"), unit="short")
stat("Infectés (dernière analyse)", "Fichiers infectés trouvés par la dernière analyse hebdomadaire.",
     prom("clamav_scan_last_infected"), 6, thr("green", (1, "red")))

panels.append({"id": len(panels) + 1, "type": "timeseries", "title": "Détections dans le temps",
               "description": "Nombre de fichiers infectés détectés. Une ligne à 0 signifie qu'aucune menace n'a été trouvée.",
               "gridPos": place(24, 7), "datasource": LOKI,
               "targets": [loki('sum(count_over_time({job="clamav"} |= "FOUND" [$__auto])) or vector(0)', "Détections")],
               "fieldConfig": {"defaults": {"min": 0, "decimals": 0, "color": {"mode": "fixed", "fixedColor": "red"},
                                            "custom": {"drawStyle": "bars", "fillOpacity": 60, "lineWidth": 1}}, "overrides": []},
               "options": {"legend": {"showLegend": False}, "tooltip": {"mode": "single"}}})

logs("Menaces détectées", "Lignes « FOUND » des journaux clamd et clamonacc : fichier, signature reconnue.",
     '{job="clamav"} |= "FOUND"', 12, 8, "✅ Aucune menace détectée sur la période")
logs("Mises à jour et avertissements", "Journal freshclam et erreurs éventuelles des services ClamAV.",
     '{job="clamav"} |~ "(?i)error|warning|updated"', 12, 8, "Aucun avertissement sur la période")

dash = {"uid": "clamav-overview", "title": "ClamAV", "tags": ["RedOne", "AP2", "clamav"],
        "description": "Antivirus ClamAV de SRV-SUPERVISION : état, signatures, détections",
        "timezone": "browser", "refresh": "1m", "time": {"from": "now-24h", "to": "now"}, "schemaVersion": 41,
        "links": [{"title": "Centre de supervision sécurité", "type": "link", "url": "/d/redone-soc", "icon": "dashboard"}],
        "panels": panels}
json.dump(dash, open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False, indent=2)
print("panneaux :", len(panels))

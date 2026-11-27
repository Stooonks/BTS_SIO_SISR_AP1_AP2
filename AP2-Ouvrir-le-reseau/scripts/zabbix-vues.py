#!/usr/bin/env python3
# Zabbix : vues natives RedOne. Idempotent (recrée les vues à chaque exécution).
#  - tableau de bord « RedOne – Routeur R-REDONE » (valeurs, graphiques, problèmes du routeur)
#  (la carte réseau est dans zabbix-carte.py)
# Usage (sur SRV-ZABBIX, en root) : python3 zabbix-vues.py
import json, urllib.request

API = 'http://localhost/zabbix/api_jsonrpc.php'
acces = dict(l.strip().split('=', 1) for l in open('/root/zabbix-acces.txt') if '=' in l)


def call(method, params, auth=None):
    h = {'Content-Type': 'application/json-rpc'}
    if auth:
        h['Authorization'] = 'Bearer ' + auth
    r = json.load(urllib.request.urlopen(urllib.request.Request(
        API, json.dumps({'jsonrpc': '2.0', 'method': method, 'params': params, 'id': 1}).encode(), h)))
    if 'error' in r:
        raise RuntimeError(f"{method}: {r['error']['data']}")
    return r['result']


T = call('user.login', {'username': 'Admin', 'password': acces['ADMIN_PASSWORD']})
A = lambda m, p: call(m, p, T)

rtr = A('host.get', {'filter': {'host': 'R-REDONE'}, 'output': ['hostid']})[0]['hostid']
items = {i['name']: i['itemid'] for i in A('item.get', {'hostids': rtr, 'output': ['name', 'itemid']})}
item = lambda motif: next(v for k, v in items.items() if motif in k)
graphes = {g['name']: g['graphid'] for g in A('graph.get', {'hostids': rtr, 'output': ['name', 'graphid']})}
graphe = lambda motif: next((v for k, v in graphes.items() if motif in k), None)


def w_item(nom, itemid, x, y, w=12, h=3):
    return {'type': 'item', 'name': nom, 'x': x, 'y': y, 'width': w, 'height': h, 'view_mode': 0,
            'fields': [{'type': 4, 'name': 'itemid.0', 'value': itemid}, {'type': 0, 'name': 'show.0', 'value': 2},
                       {'type': 0, 'name': 'show.1', 'value': 4}, {'type': 0, 'name': 'adv_conf', 'value': 0}]}


def w_graphe(nom, graphid, x, y, w=36, h=5):
    return {'type': 'graph', 'name': nom, 'x': x, 'y': y, 'width': w, 'height': h, 'view_mode': 0,
            'fields': [{'type': 0, 'name': 'source_type', 'value': 0}, {'type': 6, 'name': 'graphid.0', 'value': graphid}]}


widgets = [
    w_item('Routeur joignable (ping)', item('ICMP ping'), 0, 0),
    w_item('Supervision SNMPv3', item('SNMP agent availability'), 12, 0),
    w_item('Port G0/0/0', next(v for k, v in items.items() if 'Gi0/0/0' in k and 'Operational status' in k), 24, 0),
    w_item('Allumé depuis', item('Uptime (network)'), 36, 0),
    w_item('Temps de réponse', item('ICMP response time'), 48, 0),
    w_item('Processeur', item('CPU utilization'), 60, 0),
    {'type': 'problems', 'name': 'Problèmes en cours sur le routeur', 'x': 0, 'y': 3, 'width': 72, 'height': 4, 'view_mode': 0,
     'fields': [{'type': 3, 'name': 'hostids.0', 'value': rtr}, {'type': 0, 'name': 'show_lines', 'value': 10}]},
]
cases = [(0, 7), (36, 7), (0, 12), (36, 12)]   # grille de 2 graphiques par ligne
for motif, titre in (('Gi0/0/0', 'Trafic du port G0/0/0 (réseau de la salle)'), ('CPU utilization', 'Processeur'),
                     ('Memory utilization', 'Mémoire')):
    g = graphe(motif)
    if g:
        x, yy = cases.pop(0)
        widgets.append(w_graphe(titre, g, x, yy))

for d in A('dashboard.get', {'output': ['dashboardid'], 'filter': {'name': 'RedOne – Routeur R-REDONE'}}):
    A('dashboard.delete', [d['dashboardid']])
A('dashboard.create', {'name': 'RedOne – Routeur R-REDONE', 'display_period': 30, 'auto_start': 1,
                       'pages': [{'widgets': widgets}]})
print('tableau de bord créé :', len(widgets), 'widgets, graphiques trouvés :', list(graphes))

# La carte réseau est créée par zabbix-carte.py (schéma de l'infrastructure et page d'accueil).

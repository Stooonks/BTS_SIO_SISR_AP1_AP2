#!/usr/bin/env python3
# Zabbix : schéma de l'infrastructure RedOne (carte réseau avec toutes les adresses IP) et page d'accueil.
#  - supprime l'ancienne carte « RedOne – Infrastructure »
#  - crée la carte « RedOne – Schéma de l'infrastructure » : 3 zones (salle, VLAN 200, Visiteurs), chaque machine avec ses IP,
#    colorée selon son état (vert = OK, rouge = problème grave)
#  - crée le tableau de bord « RedOne – Accueil » (la carte en plein écran) et en fait la page d'accueil du compte Admin
# Usage (sur SRV-ZABBIX, en root) : python3 zabbix-carte.py
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

img = {i['name']: i['imageid'] for i in A('image.get', {'output': ['name'], 'filter': {'imagetype': 1}})}
hotes = {h['host']: h['hostid'] for h in A('host.get', {'output': ['host']})}
NOM = 'RedOne – Schéma de l\'infrastructure'

# ------------------------------------------------------------------ éléments : (id, hôte Zabbix ou None, icône, x, y, étiquette)
E = [
    # Réseau de la salle (administration) 192.168.100.0/24
    ('internet', None, 'Cloud_(64)', 1170, 150, 'Internet'),
    ('admin', None, 'Workstation_(64)', 90, 50, "Poste d'administration\n192.168.100.141"),
    ('pve', None, 'Rackmountable_2U_server_3D_(64)', 330, 50, 'Proxmox VE (hyperviseur)\n192.168.100.2'),
    ('sw_salle', None, 'Switch_(64)', 640, 150, 'Réseau de la salle\n192.168.100.0/24'),
    ('pfsense', 'PFSENSE', 'Firewall_(64)', 900, 50, 'pfSense (passerelle)\n192.168.100.1  |  10.2.1.1'),
    ('routeur', 'R-REDONE', 'Router_symbol_(64)', 1430, 50, 'R-REDONE (Cisco C1111-4P)\n192.168.100.212'),
    # VLAN 200 – serveurs et postes RedOne 10.2.1.0/24
    ('sw_v200', None, 'Switch_(64)', 640, 350, 'VLAN 200 (vmbr2)\n10.2.1.0/24'),
    ('ad', 'SRV-AD', 'Server_(64)', 60, 520, 'SRV-AD\nAD, DNS, DHCP\n10.2.1.10'),
    ('ad2', 'SRV-AD2', 'Server_(64)', 260, 520, 'SRV-AD2\nAD, DNS\n10.2.1.9'),
    ('nas', 'TRUENAS', 'Disk_array_2D_(64)', 460, 520, 'TrueNAS\nstockage\n10.2.1.7'),
    ('veeam', 'SRV-VEEAM', 'Server_(64)', 660, 520, 'SRV-VEEAM\nsauvegarde\n10.2.1.53  |  192.168.100.211'),
    ('glpi', 'SRV-GLPI', 'Server_(64)', 880, 520, 'SRV-GLPI\nparc et support\n10.2.1.50  |  192.168.100.208'),
    ('wazuh', 'SRV-WAZUH', 'Server_(64)', 1100, 520, 'SRV-WAZUH\nSIEM\n10.2.1.51  |  192.168.100.209'),
    ('zabbix', 'SRV-ZABBIX', 'Server_(64)', 160, 760, 'SRV-ZABBIX\nsupervision\n10.2.1.52  |  192.168.100.210'),
    ('sup', 'SRV-SUPERVISION', 'Server_(64)', 420, 760, 'SRV-SUPERVISION\nGrafana, Prometheus, Loki\n10.2.1.3  |  192.168.100.204'),
    ('poste1', 'POSTE-1', 'Workstation_(64)', 720, 760, 'POSTE-1\n10.2.1.11'),
    ('poste2', 'POSTE-2', 'Workstation_(64)', 960, 760, 'POSTE-2\n10.2.1.15'),
    # Réseau Visiteurs (isolé : DNS et Internet seulement)
    ('vis1', None, 'Notebook_(64)', 1385, 520, 'Visiteurs – port G0/0/1\n10.2.3.0/24\npasserelle 10.2.3.1\n(NAT + ACL)'),
    ('vis2', None, 'Hub_(64)', 1570, 700, 'Visiteurs – VLAN 150\n(4 prises du switch)\n10.2.4.0/24\npasserelle 10.2.4.1\n(NAT + ACL)'),
]
selements, ids = [], {}
for n, (cle, hote, icone, x, y, label) in enumerate(E, 1):
    ids[cle] = str(n)
    s = {'selementid': str(n), 'iconid_off': img[icone], 'label': label, 'x': x, 'y': y, 'label_location': 0}
    if hote and hote in hotes:
        s.update(elementtype=0, elements=[{'hostid': hotes[hote]}])
    else:
        s.update(elementtype=4)            # simple image (équipement non supervisé ou réseau)
    selements.append(s)

VERT, GRIS, ORANGE, BLEU = '2E7D32', '757575', 'EF6C00', '1565C0'
L = [  # (de, vers, couleur, style 0=continu 2=pointillé, étiquette)
    ('admin', 'sw_salle', GRIS, 0, ''), ('pve', 'sw_salle', GRIS, 0, ''), ('pfsense', 'sw_salle', GRIS, 0, ''),
    ('routeur', 'sw_salle', BLEU, 0, ''), ('pfsense', 'internet', GRIS, 2, ''),
    ('pfsense', 'sw_v200', VERT, 0, '10.2.1.1'),
    ('ad', 'sw_v200', VERT, 0, ''), ('ad2', 'sw_v200', VERT, 0, ''), ('nas', 'sw_v200', VERT, 0, ''),
    ('veeam', 'sw_v200', VERT, 0, ''), ('glpi', 'sw_v200', VERT, 0, ''), ('wazuh', 'sw_v200', VERT, 0, ''),
    ('zabbix', 'sw_v200', VERT, 0, ''), ('sup', 'sw_v200', VERT, 0, ''), ('poste1', 'sw_v200', VERT, 0, ''),
    ('poste2', 'sw_v200', VERT, 0, ''),
    ('routeur', 'vis1', ORANGE, 0, ''), ('routeur', 'vis2', ORANGE, 0, ''),
]
liens = [{'selementid1': ids[a], 'selementid2': ids[b], 'color': c, 'drawtype': d, 'label': lab} for a, b, c, d, lab in L]

ZONES = [  # (texte, x, y, largeur, hauteur, fond, bordure)
    ("RÉSEAU DE LA SALLE – 192.168.100.0/24 (administration, accès Internet)", 20, 20, 1680, 250, 'E3F2FD', '1565C0'),
    ("VLAN 200 – SERVEURS ET POSTES REDONE – 10.2.1.0/24 (passerelle pfSense 10.2.1.1)", 20, 290, 1320, 630, 'E8F5E9', '2E7D32'),
    ("RÉSEAU VISITEURS – isolé : DNS et Internet seulement", 1360, 290, 340, 630, 'FFF3E0', 'EF6C00'),
]
formes = [{'type': 0, 'x': x, 'y': y, 'width': w, 'height': h, 'text': t, 'font': 9, 'font_size': 12, 'font_color': '000000',
           'text_halign': 1, 'text_valign': 1, 'background_color': bg, 'border_type': 1, 'border_width': 2,
           'border_color': bc, 'zindex': n} for n, (t, x, y, w, h, bg, bc) in enumerate(ZONES)]
formes.append({'type': 0, 'x': 30, 'y': 880, 'width': 1300, 'height': 30, 'font': 9, 'font_size': 10, 'font_color': '424242',
               'text': "Deux adresses = VLAN 200  |  réseau de la salle.   Couleur de l'icône : état Zabbix (problème de gravité haute ou plus).",
               'text_halign': 1, 'text_valign': 0, 'background_color': '', 'border_type': 0, 'border_width': 0,
               'border_color': '000000', 'zindex': 10})

for m in A('map.get', {'output': ['sysmapid', 'name']}):
    if m['name'] in ('RedOne – Infrastructure', NOM):
        A('map.delete', [m['sysmapid']])
carte = A('map.create', {'name': NOM, 'width': 1720, 'height': 930, 'label_type': 0, 'label_location': 0,
                         'highlight': 1, 'expandproblem': 0, 'markelements': 1, 'show_unack': 0, 'severity_min': 4,
                         'label_format': 0, 'selements': selements, 'links': liens, 'shapes': formes})['sysmapids'][0]
print('carte créée :', carte, '-', len(selements), 'éléments,', len(liens), 'liens')

# ------------------------------------------------------------------ page d'accueil
for d in A('dashboard.get', {'output': ['dashboardid', 'name']}):
    if d['name'] == 'RedOne – Accueil':
        A('dashboard.delete', [d['dashboardid']])
tdb = A('dashboard.create', {'name': 'RedOne – Accueil', 'display_period': 30, 'auto_start': 1, 'pages': [{'widgets': [
    {'type': 'map', 'name': NOM, 'x': 0, 'y': 0, 'width': 72, 'height': 16, 'view_mode': 0,
     'fields': [{'type': 8, 'name': 'sysmapid.0', 'value': carte}]}]}]})['dashboardids'][0]
admin = A('user.get', {'filter': {'username': 'Admin'}, 'output': ['userid']})[0]['userid']
A('user.update', {'userid': admin, 'url': f'zabbix.php?action=dashboard.view&dashboardid={tdb}'})
print('page d\'accueil : tableau de bord', tdb)

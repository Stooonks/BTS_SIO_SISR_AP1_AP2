#!/usr/bin/env python3
# Zabbix : éléments « trapper » Veeam (reçus des serveurs) + déclencheurs. Idempotent.
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
ALLOWED = '10.2.1.10,10.2.1.9,10.2.1.53'

# Correspondance des valeurs
vm = A('valuemap.get', {'filter': {'name': 'Veeam - résultat'}, 'output': ['valuemapid']})
MAPS = {}
for name, mp in (('Veeam - résultat', {'0': 'Succès', '1': 'Avertissement', '2': 'Échec', '3': 'Aucune sauvegarde'}),
                 ('Veeam - copie', {'0': 'OK', '1': 'Échec', '2': 'Jamais exécutée'})):
    MAPS[name] = mp

ITEMS_SRV = [  # clé, nom, type de valeur (0 float, 3 entier), unité, table de correspondance
    ('veeam.result', 'Veeam : résultat de la dernière sauvegarde', 3, '', 'Veeam - résultat'),
    ('veeam.age_h', 'Veeam : âge de la dernière sauvegarde', 0, 'h', None),
    ('veeam.points', 'Veeam : points de restauration', 3, '', None),
    ('veeam.size_gb', 'Veeam : taille des sauvegardes', 0, 'Go', None),
]
ITEMS_REPO = [
    ('veeam.repo.free_gb', 'Dépôt Veeam : espace libre', 0, 'Go', None),
    ('veeam.repo.free_pct', 'Dépôt Veeam : espace libre en %', 0, '%', None),
    ('veeam.repo.used_gb', 'Dépôt Veeam : volume des sauvegardes', 0, 'Go', None),
    ('veeam.copy.result', 'Copie TrueNAS : résultat', 3, '', 'Veeam - copie'),
    ('veeam.copy.age_h', 'Copie TrueNAS : âge de la dernière copie', 0, 'h', None),
]


def hostid(name):
    return A('host.get', {'filter': {'host': name}, 'output': ['hostid']})[0]['hostid']


def valuemap(hid, name):
    r = A('valuemap.get', {'hostids': hid, 'filter': {'name': name}, 'output': ['valuemapid']})
    if r:
        return r[0]['valuemapid']
    return A('valuemap.create', {'hostid': hid, 'name': name,
                                 'mappings': [{'value': k, 'newvalue': v} for k, v in MAPS[name].items()]})['valuemapids'][0]


def items(host, defs):
    hid = hostid(host)
    for key, name, vt, unit, mp in defs:
        p = {'name': name, 'key_': key, 'type': 2, 'value_type': vt, 'units': unit, 'trapper_hosts': ALLOWED,
             'history': '90d', 'tags': [{'tag': 'component', 'value': 'sauvegarde'}],
             'description': 'Envoyé toutes les 15 min par C:\\Scripts\\veeam-status.ps1 (tâche planifiée SYSTEM).'}
        if mp:
            p['valuemapid'] = valuemap(hid, mp)
        ex = A('item.get', {'hostids': hid, 'filter': {'key_': key}, 'output': ['itemid']})
        if ex:
            p.pop('key_'); p.pop('type'); p.pop('value_type')
            A('item.update', dict(p, itemid=ex[0]['itemid']))
        else:
            A('item.create', dict(p, hostid=hid))
    return hid


def trigger(desc, expr, prio, comment):
    if not A('trigger.get', {'filter': {'description': desc}, 'output': ['triggerid']}):
        A('trigger.create', {'description': desc, 'expression': expr, 'priority': prio, 'comments': comment,
                             'tags': [{'tag': 'component', 'value': 'sauvegarde'}]})
        print('déclencheur :', desc)


for h in ('SRV-AD', 'SRV-AD2'):
    items(h, ITEMS_SRV)
    trigger(f'{h} : sauvegarde Veeam en ÉCHEC', f'last(/{h}/veeam.result)=2', 4,
            'La dernière sauvegarde Veeam a échoué : voir la console Veeam du serveur et le journal « Veeam Agent ».')
    trigger(f'{h} : sauvegarde Veeam terminée avec avertissement', f'last(/{h}/veeam.result)=1', 2, 'Sauvegarde partielle.')
    trigger(f'{h} : aucune sauvegarde Veeam depuis plus de 26 h', f'last(/{h}/veeam.age_h)>26', 3,
            'La sauvegarde quotidienne de 0 h 30 ne s\'est pas faite (serveur éteint, dépôt injoignable…).')
    trigger(f'{h} : état Veeam non reçu depuis 1 h', f'nodata(/{h}/veeam.result,1h)=1', 2,
            'Le script veeam-status.ps1 ne remonte plus rien (tâche planifiée arrêtée ou serveur injoignable).')
    print('éléments Veeam :', h)

items('SRV-VEEAM', ITEMS_REPO)
trigger('SRV-VEEAM : dépôt de sauvegarde presque plein (< 15 %)', 'last(/SRV-VEEAM/veeam.repo.free_pct)<15', 4,
        'Le disque S: de SRV-VEEAM se remplit : réduire la rétention ou agrandir le disque.')
trigger('SRV-VEEAM : copie vers le TrueNAS en échec', 'last(/SRV-VEEAM/veeam.copy.result)=1', 3,
        'robocopy a échoué : voir C:\\Scripts\\copie-truenas.log sur SRV-VEEAM (partage copie-veeam, quota 50 Go).')
trigger('SRV-VEEAM : aucune copie vers le TrueNAS depuis plus de 26 h', 'last(/SRV-VEEAM/veeam.copy.age_h)>26', 3,
        'La copie de 4 h ne s\'est pas exécutée.')
print('éléments dépôt : SRV-VEEAM')

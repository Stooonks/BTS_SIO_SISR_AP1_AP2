#!/usr/bin/env python3
# Zabbix : hôte « R-REDONE » (routeur Cisco C1111-4P) supervisé en SNMPv3 authPriv (le modèle Cisco inclut le ping). Idempotent.
# Les clés SNMPv3 sont lues dans /root/zabbix-acces.txt (SNMP_AUTH=..., SNMP_PRIV=...), jamais dans ce dépôt.
# Usage (sur SRV-ZABBIX, en root) : python3 zabbix-routeur.py
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

groupe = A('hostgroup.get', {'filter': {'name': 'RedOne/Réseau et stockage'}, 'output': ['groupid']})[0]['groupid']
modeles = [{'templateid': t['templateid']} for t in
           A('template.get', {'filter': {'host': ['Cisco IOS by SNMP']}, 'output': ['templateid']})]

interface = {'type': 2, 'main': 1, 'useip': 1, 'ip': '192.168.100.212', 'dns': '', 'port': '161',
             'details': {'version': 3, 'bulk': 1, 'securityname': 'zabbix', 'securitylevel': 2,   # authPriv
                         'authprotocol': 1, 'authpassphrase': '{$SNMPV3_AUTH}',                   # SHA1
                         'privprotocol': 1, 'privpassphrase': '{$SNMPV3_PRIV}', 'contextname': ''}}  # AES-128
macros = [{'macro': '{$SNMPV3_AUTH}', 'value': acces['SNMP_AUTH'], 'type': 1, 'description': 'Clé SNMPv3 auth (secrète)'},
          {'macro': '{$SNMPV3_PRIV}', 'value': acces['SNMP_PRIV'], 'type': 1, 'description': 'Clé SNMPv3 priv (secrète)'}]
champs = {'name': 'R-REDONE (routeur Cisco)', 'groups': [{'groupid': groupe}], 'templates': modeles, 'macros': macros,
          'description': 'Routeur Cisco C1111-4P, IOS-XE 16.8. Administration SSH (poste admin uniquement), '
                         'journaux syslog vers Wazuh, supervision SNMPv3 authPriv.',
          'tags': [{'tag': 'role', 'value': 'routeur'}, {'tag': 'projet', 'value': 'AP2'}]}

existant = A('host.get', {'filter': {'host': 'R-REDONE'}, 'output': ['hostid'], 'selectInterfaces': ['interfaceid']})
if existant:
    h = existant[0]
    A('host.update', {'hostid': h['hostid'], **champs})
    A('hostinterface.update', {'interfaceid': h['interfaces'][0]['interfaceid'], **interface})
    print('hôte R-REDONE mis à jour')
else:
    A('host.create', {'host': 'R-REDONE', 'interfaces': [interface], **champs})
    print('hôte R-REDONE créé')

# ---- Sauvegarde de la configuration (envoyée par SRV-VEEAM, script sauvegarde-routeur.ps1) ----
hid = A('host.get', {'filter': {'host': 'R-REDONE'}, 'output': ['hostid']})[0]['hostid']
vm = A('valuemap.get', {'hostids': hid, 'filter': {'name': 'Sauvegarde routeur'}, 'output': ['valuemapid']})
if not vm:
    vm = [{'valuemapid': A('valuemap.create', {'hostid': hid, 'name': 'Sauvegarde routeur', 'mappings': [
        {'value': '0', 'newvalue': 'Succès'}, {'value': '1', 'newvalue': 'Échec'}]})['valuemapids'][0]}]
ELEMENTS = [  # (clé, nom, type de valeur, unité, correspondance)
    ('routeur.sauvegarde.resultat', 'Sauvegarde config : résultat', 3, '', vm[0]['valuemapid']),
    ('routeur.sauvegarde.versions', 'Sauvegarde config : versions conservées', 3, '', '0'),
    ('routeur.sauvegarde.horodatage', 'Sauvegarde config : dernière exécution', 3, 'unixtime', '0')]
for cle, nom, vt, unite, vmid in ELEMENTS:
    p = {'name': nom, 'type': 2, 'value_type': vt, 'units': unite, 'valuemapid': vmid,
         'trapper_hosts': '10.2.1.53,192.168.100.211', 'history': '90d', 'trends': '365d',
         'tags': [{'tag': 'component', 'value': 'sauvegarde'}]}
    ex = A('item.get', {'hostids': hid, 'filter': {'key_': cle}, 'output': ['itemid']})
    A('item.update', {'itemid': ex[0]['itemid'], **p}) if ex else A('item.create', {'hostid': hid, 'key_': cle, **p})
DECL = [
    ('Sauvegarde de la configuration du routeur en échec', 'last(/R-REDONE/routeur.sauvegarde.resultat)=1', 4),
    ('Configuration du routeur non sauvegardée depuis plus de 26 h', 'now()-last(/R-REDONE/routeur.sauvegarde.horodatage)>26h', 3)]
for desc, expr, prio in DECL:
    ex = A('trigger.get', {'hostids': hid, 'filter': {'description': desc}, 'output': ['triggerid']})
    p = {'description': desc, 'expression': expr, 'priority': prio, 'tags': [{'tag': 'component', 'value': 'sauvegarde'}]}
    A('trigger.update', {'triggerid': ex[0]['triggerid'], **p}) if ex else A('trigger.create', p)
print('éléments et déclencheurs de sauvegarde de la configuration : OK')

# ---- Prises Visiteurs : un débranchement est normal, pas d'alerte « Link down » (macro {$IFCONTROL:"<port>"}=0) ----
existantes = {m['macro'] for m in A('usermacro.get', {'hostids': hid, 'output': ['macro']})}
for port in ('Gi0/1/0', 'Gi0/1/1', 'Gi0/1/2', 'Gi0/1/3', 'Vl150', 'Gi0/0/1'):
    macro = '{$IFCONTROL:"%s"}' % port
    if macro not in existantes:
        A('usermacro.create', {'hostid': hid, 'macro': macro, 'value': '0',
                               'description': 'prise visiteur : débranchement normal, pas d\'alerte Link down'})
print('alertes Link down désactivées sur les prises Visiteurs')

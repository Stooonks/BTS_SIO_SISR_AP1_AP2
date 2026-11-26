#!/usr/bin/env python3
# Configuration de Zabbix 7.0 pour RedOne via l'API JSON-RPC (idempotent)
import json, os, secrets, string, sys, urllib.request

API = 'http://localhost/zabbix/api_jsonrpc.php'
ACCES = '/root/zabbix-acces.txt'
TOKEN_FILE = '/root/.zabbix-grafana-token'
_auth = None


def call(method, params):
    body = {'jsonrpc': '2.0', 'method': method, 'params': params, 'id': 1}
    headers = {'Content-Type': 'application/json-rpc'}
    if _auth and method not in ('user.login', 'apiinfo.version'):
        headers['Authorization'] = 'Bearer ' + _auth
    r = json.load(urllib.request.urlopen(urllib.request.Request(API, json.dumps(body).encode(), headers)))
    if 'error' in r:
        raise RuntimeError(f"{method}: {r['error']['data']}")
    return r['result']


def gen(n=20):
    a = string.ascii_letters + string.digits
    return ''.join(secrets.choice(a) for _ in range(n))


def lire_acces():
    d = {}
    if os.path.exists(ACCES):
        for l in open(ACCES):
            if '=' in l:
                k, v = l.strip().split('=', 1)
                d[k] = v
    return d


acces = lire_acces()
print('API Zabbix', call('apiinfo.version', {}))

# ---------- Connexion et mot de passe Admin ----------
if 'ADMIN_PASSWORD' in acces:
    _auth = call('user.login', {'username': 'Admin', 'password': acces['ADMIN_PASSWORD']})
else:
    _auth = call('user.login', {'username': 'Admin', 'password': 'zabbix'})
    new = gen()
    admin = call('user.get', {'filter': {'username': 'Admin'}})[0]
    call('user.update', {'userid': admin['userid'], 'current_passwd': 'zabbix', 'passwd': new})
    acces['ADMIN_PASSWORD'] = new
    with open(ACCES, 'w') as f:
        f.write(f"URL=http://192.168.100.210/zabbix\nADMIN_USER=Admin\nADMIN_PASSWORD={new}\n")
    os.chmod(ACCES, 0o600)
    _auth = call('user.login', {'username': 'Admin', 'password': new})
    print('Mot de passe Admin changé (défaut zabbix supprimé)')

admin = call('user.get', {'filter': {'username': 'Admin'}})[0]
call('user.update', {'userid': admin['userid'], 'lang': 'fr_FR', 'timezone': 'Europe/Paris', 'name': 'Administrateur', 'surname': 'RedOne'})
call('settings.update', {'default_lang': 'fr_FR', 'default_timezone': 'Europe/Paris'})

# ---------- Groupes d'hôtes ----------
GROUPES = ['RedOne/Serveurs Linux', 'RedOne/Serveurs Windows', 'RedOne/Postes de travail', 'RedOne/Réseau et stockage']
gid = {}
for g in GROUPES:
    r = call('hostgroup.get', {'filter': {'name': g}})
    gid[g] = r[0]['groupid'] if r else call('hostgroup.create', {'name': g})['groupids'][0]


def tpl(name):
    r = call('template.get', {'filter': {'host': name}})
    if not r:
        raise RuntimeError('modèle introuvable : ' + name)
    return {'templateid': r[0]['templateid']}


T_LINUX, T_WIN, T_ICMP, T_ZBX = (tpl('Linux by Zabbix agent'), tpl('Windows by Zabbix agent'),
                                 tpl('ICMP Ping'), tpl('Zabbix server health'))

# ---------- Hôtes ----------
HOTES = [
    # nom, ip, groupe, modèles, agent ?, description
    ('SRV-ZABBIX', '127.0.0.1', 'RedOne/Serveurs Linux', [T_LINUX, T_ZBX], True,
     'VM 210 - serveur Zabbix 7.0 LTS (10.2.1.52 / 192.168.100.210)'),
    ('SRV-SUPERVISION', '10.2.1.3', 'RedOne/Serveurs Linux', [T_LINUX, T_ICMP], True,
     'VM 204 - Prometheus, Grafana, Loki, ClamAV (10.2.1.3 / 192.168.100.204)'),
    ('SRV-GLPI', '10.2.1.50', 'RedOne/Serveurs Linux', [T_LINUX, T_ICMP], True, 'VM 208 - GLPI 12 (gestion de parc, tickets)'),
    ('SRV-WAZUH', '10.2.1.51', 'RedOne/Serveurs Linux', [T_LINUX, T_ICMP], True, 'VM 209 - Wazuh 4.14 (SIEM)'),
    ('SRV-AD', '10.2.1.10', 'RedOne/Serveurs Windows', [T_WIN, T_ICMP], True, 'VM 105 - contrôleur de domaine REDONE (RedOne.local), DNS'),
    ('SRV-AD2', '10.2.1.9', 'RedOne/Serveurs Windows', [T_WIN, T_ICMP], True, 'VM 206 - contrôleur de domaine secondaire'),
    ('SRV-VEEAM', '10.2.1.53', 'RedOne/Serveurs Windows', [T_WIN, T_ICMP], True, 'VM 211 - Veeam, dépôt de sauvegarde SRV-VEEAM/Sauvegardes (10.2.1.53 / 192.168.100.211)'),
    ('POSTE-1', '10.2.1.11', 'RedOne/Postes de travail', [T_WIN], True, 'VM 112 - poste Windows 11 joint au domaine'),
    ('POSTE-2', '10.2.1.15', 'RedOne/Postes de travail', [T_WIN], True, 'VM 203 - poste Windows 11 joint au domaine'),
    ('PFSENSE', '10.2.1.1', 'RedOne/Réseau et stockage', [T_ICMP], False, 'VM 100 (commune à la salle) - pare-feu / passerelle du VLAN 200'),
    ('TRUENAS', '10.2.1.7', 'RedOne/Réseau et stockage', [T_ICMP], False, 'VM 205 - stockage (NAS)'),
]
hid = {}
for nom, ip, grp, tpls, agent, desc in HOTES:
    iface = {'type': 1 if agent else 1, 'main': 1, 'useip': 1, 'ip': ip, 'dns': '', 'port': '10050'}
    r = call('host.get', {'filter': {'host': nom}, 'selectInterfaces': ['interfaceid']})
    if nom == 'SRV-ZABBIX' and not r:
        r = call('host.get', {'filter': {'host': 'Zabbix server'}, 'selectInterfaces': ['interfaceid']})
    if r:
        h = r[0]
        call('host.update', {'hostid': h['hostid'], 'host': nom, 'name': nom, 'description': desc,
                             'groups': [{'groupid': gid[grp]}], 'templates': tpls})
        call('hostinterface.update', {'interfaceid': h['interfaces'][0]['interfaceid'], 'ip': ip})
        hid[nom] = h['hostid']
        print('mis à jour :', nom)
    else:
        hid[nom] = call('host.create', {'host': nom, 'name': nom, 'description': desc, 'interfaces': [iface],
                                        'groups': [{'groupid': gid[grp]}], 'templates': tpls,
                                        'tags': [{'tag': 'site', 'value': 'RedOne'}]})['hostids'][0]
        print('créé :', nom)

# ---------- Scénarios web (disponibilité des applications) ----------
WEB = [
    ('SRV-GLPI', 'GLPI - page de connexion', 'https://10.2.1.50/', 'GLPI'),
    ('SRV-WAZUH', 'Wazuh - tableau de bord', 'https://10.2.1.51/', ''),
    ('SRV-SUPERVISION', 'Grafana - interface', 'http://10.2.1.3:3000/login', 'Grafana'),
    ('SRV-ZABBIX', 'Zabbix - interface web', 'http://localhost/zabbix/index.php', 'Zabbix'),
]
for host, nom, url, texte in WEB:
    if call('httptest.get', {'hostids': hid[host], 'filter': {'name': nom}}):
        continue
    step = {'name': 'Accueil', 'url': url, 'no': 1, 'status_codes': '200', 'follow_redirects': 1, 'timeout': '15s'}
    if texte:
        step['required'] = texte
    call('httptest.create', {'name': nom, 'hostid': hid[host], 'delay': '1m', 'retries': 2,
                             'verify_peer': 0, 'verify_host': 0, 'steps': [step]})
    call('trigger.create', {'description': f'{nom} indisponible',
                            'expression': f'last(/{host}/web.test.fail[{nom}])<>0',
                            'priority': 4, 'comments': f"Le scénario web « {nom} » échoue ({url})."})
    print('scénario web :', nom)

# ---------- Utilisateur en lecture seule pour Grafana ----------
ug = call('usergroup.get', {'filter': {'name': 'Grafana (lecture seule)'}})
rights = [{'id': gid[g], 'permission': 2} for g in GROUPES]
if ug:
    ugid = ug[0]['usrgrpid']
    call('usergroup.update', {'usrgrpid': ugid, 'hostgroup_rights': rights})
else:
    ugid = call('usergroup.create', {'name': 'Grafana (lecture seule)', 'gui_access': 3,
                                     'hostgroup_rights': rights})['usrgrpids'][0]
gu = call('user.get', {'filter': {'username': 'grafana'}})
if gu:
    guid = gu[0]['userid']
else:
    guid = call('user.create', {'username': 'grafana', 'name': 'Grafana', 'surname': 'API', 'passwd': gen(32),
                                'roleid': '1', 'usrgrps': [{'usrgrpid': ugid}]})['userids'][0]
if not os.path.exists(TOKEN_FILE):
    tid = call('token.create', {'name': 'grafana-datasource', 'userid': guid,
                                'description': 'Source de données Zabbix dans Grafana (lecture seule)'})['tokenids'][0]
    tok = call('token.generate', [tid])[0]['token']
    with open(TOKEN_FILE, 'w') as f:
        f.write(tok)
    os.chmod(TOKEN_FILE, 0o600)
    print('jeton API Grafana créé')

# ---------- Action : enregistrer les problèmes (journal) ----------
print('Hôtes :', ', '.join(sorted(hid)))

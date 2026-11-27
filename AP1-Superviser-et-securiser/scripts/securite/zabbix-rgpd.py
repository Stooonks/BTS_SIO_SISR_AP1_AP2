#!/usr/bin/env python3
# RGPD sur Zabbix : durées de conservation (nettoyage automatique) et compte invité désactivé
import json, urllib.request
acces = dict(l.strip().split('=', 1) for l in open('/root/zabbix-acces.txt') if '=' in l)


def call(m, p, a=None):
    h = {'Content-Type': 'application/json-rpc'}
    if a:
        h['Authorization'] = 'Bearer ' + a
    r = json.load(urllib.request.urlopen(urllib.request.Request('http://localhost/zabbix/api_jsonrpc.php',
        json.dumps({'jsonrpc': '2.0', 'method': m, 'params': p, 'id': 1}).encode(), h)))
    if 'error' in r:
        raise RuntimeError(f"{m}: {r['error']['data']}")
    return r['result']


T = call('user.login', {'username': 'Admin', 'password': acces['ADMIN_PASSWORD']})
# Housekeeping global : on force les mêmes durées pour tous les éléments
call('housekeeping.update', {
    'hk_events_mode': 1, 'hk_events_trigger': '365d', 'hk_events_internal': '30d', 'hk_events_discovery': '30d',
    'hk_events_autoreg': '30d', 'hk_services_mode': 1, 'hk_services': '365d',
    'hk_sessions_mode': 1, 'hk_sessions': '30d',          # sessions web (adresse IP, utilisateur)
    'hk_history_mode': 1, 'hk_history_global': 1, 'hk_history': '90d',
    'hk_trends_mode': 1, 'hk_trends_global': 1, 'hk_trends': '365d'}, T)
call('housekeeping.update', {'hk_audit_mode': 1, 'hk_audit': '365d'}, T)
print('conservation : historique 90 j, tendances et événements 365 j, sessions 30 j, audit 365 j')

# Compte « guest » : désactivé (aucun accès anonyme)
g = call('usergroup.get', {'filter': {'name': 'Guests'}, 'output': ['usrgrpid', 'users_status', 'gui_access']}, T)
if g:
    call('usergroup.update', {'usrgrpid': g[0]['usrgrpid'], 'users_status': 1, 'gui_access': 3}, T)
    print('groupe Guests : désactivé, sans accès à l\'interface')
s = call('authentication.get', {'output': ['passwd_min_length', 'passwd_check_rules']}, T)
call('authentication.update', {'passwd_min_length': 12, 'passwd_check_rules': 15}, T)
print('mots de passe Zabbix : 12 caractères minimum, 4 types de caractères, pas de mot du dictionnaire')

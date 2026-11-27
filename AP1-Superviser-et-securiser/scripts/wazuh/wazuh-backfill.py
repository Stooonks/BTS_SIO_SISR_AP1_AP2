# Rejoue dans Loki l'historique des alertes Wazuh (niveau >= 3) d'un fichier alerts.json
import json, sys, urllib.request, urllib.error, collections, datetime
LOKI = 'http://10.2.1.3:3100'
streams = collections.defaultdict(list)
for line in open(sys.argv[1]):
    j = json.loads(line)
    if j['rule']['level'] < 3: continue
    ts = int(datetime.datetime.strptime(j['timestamp'], '%Y-%m-%dT%H:%M:%S.%f%z').timestamp() * 1e9)
    streams[(j['agent']['name'], str(j['rule']['level']))].append([str(ts), line.rstrip('\n')])
n = 0
for (agent, level), vals in streams.items():
    vals.sort()
    for i in range(0, len(vals), 500):
        body = {'streams': [{'stream': {'job': 'wazuh', 'host': 'SRV-WAZUH', 'agent': agent, 'level': level}, 'values': vals[i:i+500]}]}
        req = urllib.request.Request(LOKI + '/loki/api/v1/push', json.dumps(body).encode(), {'Content-Type': 'application/json'})
        try:
            urllib.request.urlopen(req); n += len(vals[i:i+500])
        except urllib.error.HTTPError as e:
            print(agent, level, e.read()[:200])
print('alertes rejouees :', n)

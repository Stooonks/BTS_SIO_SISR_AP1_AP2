#!/usr/bin/env python3
# TrueNAS SCALE 25.10 : partage SMB "copie-veeam" (2e copie des sauvegardes Veeam, règle 3-2-1)
import json, subprocess, sys

PWD = open('/root/.svc-sauvegarde').read().strip()


def mid(method, *args, job=False):
    cmd = ['midclt', 'call'] + (['--job'] if job else []) + [method] + [json.dumps(a) for a in args]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode:
        raise RuntimeError(f'{method}: {r.stderr.strip()[-400:]}')
    return json.loads(r.stdout) if r.stdout.strip() else None


# 1. Compte de service SMB
u = mid('user.query', [['username', '=', 'svc-sauvegarde']])
if u:
    mid('user.update', u[0]['id'], {'password': PWD, 'smb': True})
    uid = u[0]['id']
else:
    mid('user.create', {'username': 'svc-sauvegarde', 'full_name': 'Copie des sauvegardes Veeam (SRV-VEEAM)',
                              'password': PWD, 'smb': True, 'group_create': True, 'shell': '/usr/sbin/nologin',
                              'home': '/var/empty'})
print('utilisateur svc-sauvegarde OK')

# 2. Dataset dédié avec quota (le pool Data fait ~60 Go)
ds = 'Data/sauvegardes-veeam'
if not mid('pool.dataset.query', [['id', '=', ds]]):
    mid('pool.dataset.create', {'name': ds, 'share_type': 'SMB', 'quota': 50 * 2**30, 'compression': 'LZ4',
                                'comments': 'Copie quotidienne de \\\\SRV-VEEAM\\Sauvegardes'})
print('dataset', ds, 'quota 50 Go')
mid('filesystem.setperm', {'path': '/mnt/' + ds, 'mode': '770', 'uid': 0,
                           'gid': mid('group.query', [['group', '=', 'svc-sauvegarde']])[0]['gid'],
                           'options': {'stripacl': True, 'recursive': True}}, job=True)
subprocess.run(['chown', '-R', 'svc-sauvegarde:svc-sauvegarde', '/mnt/' + ds], check=True)

# 3. Partage SMB
if not mid('sharing.smb.query', [['name', '=', 'copie-veeam']]):
    mid('sharing.smb.create', {'path': '/mnt/' + ds, 'name': 'copie-veeam', 'purpose': 'DEFAULT_SHARE',
                               'comment': 'Copie des sauvegardes Veeam (lecture/écriture : svc-sauvegarde)',
                               'browsable': False})
print('partage SMB copie-veeam')

# 4. Service SMB : SMB2/3 uniquement, démarrage automatique
mid('smb.update', {'enable_smb1': False, 'workgroup': 'REDONE0', 'description': 'TrueNAS RedOne'})
mid('service.update', 'cifs', {'enable': True})
mid('service.control', 'START', 'cifs', job=True)
print('service SMB :', [s['state'] for s in mid('service.query', [['service', '=', 'cifs']])][0])

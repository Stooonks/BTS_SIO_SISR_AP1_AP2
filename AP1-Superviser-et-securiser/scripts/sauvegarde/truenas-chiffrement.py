#!/usr/bin/env python3
# TrueNAS : copie des sauvegardes sur un dataset chiffré (ZFS natif AES-256-GCM) + SMB chiffré obligatoire
import json, subprocess, sys


def mid(method, *args, job=False):
    cmd = ['midclt', 'call'] + (['--job'] if job else []) + [method] + [json.dumps(a) for a in args]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode:
        raise RuntimeError(f'{method}: {r.stderr.strip()[-300:]}')
    out = r.stdout.strip()
    try:
        return json.loads(out) if out else None
    except json.JSONDecodeError:
        return out


etape = sys.argv[1]
NEW = 'Data/sauvegardes-veeam-chiffre'; OLD = 'Data/sauvegardes-veeam'

if etape == 'creer':
    if not mid('pool.dataset.query', [['id', '=', NEW]]):
        mid('pool.dataset.create', {'name': NEW, 'share_type': 'SMB', 'quota': 50 * 2**30, 'compression': 'LZ4',
                                    'encryption': True, 'inherit_encryption': False,
                                    'encryption_options': {'generate_key': True, 'algorithm': 'AES-256-GCM'},
                                    'comments': 'Copie chiffrée des sauvegardes Veeam (RGPD art. 32)'})
    subprocess.run(['chown', 'svc-sauvegarde:svc-sauvegarde', '/mnt/' + NEW], check=True)
    sh = mid('sharing.smb.query', [['name', '=', 'copie-veeam']])[0]
    mid('sharing.smb.update', sh['id'], {'path': '/mnt/' + NEW})
    try:
        mid('smb.update', {'encryption': 'REQUIRED'})
        print('SMB : chiffrement obligatoire')
    except RuntimeError as e:
        print('SMB chiffrement :', e)
    ds = mid('pool.dataset.query', [['id', '=', NEW]])[0]
    print('dataset', NEW, 'chiffré =', ds['encrypted'], ds.get('encryption_algorithm', {}).get('value'), '- partage copie-veeam ->', '/mnt/' + NEW)

if etape == 'nettoyer':
    if mid('pool.dataset.query', [['id', '=', OLD]]):
        mid('pool.dataset.delete', OLD, {'recursive': True})
        print('ancien dataset non chiffré supprimé :', OLD)
    print(subprocess.run(['du', '-sh', '/mnt/' + NEW], capture_output=True, text=True).stdout.strip())

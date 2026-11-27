#!/bin/bash
# RGPD (art. 32, confidentialité) : HTTPS pour Grafana (SRV-SUPERVISION) ou Zabbix (SRV-ZABBIX)
# Usage : https-rgpd.sh grafana|zabbix
set -euo pipefail
ROLE=$1

cert() {  # cert <dossier> <CN> <SAN>
  mkdir -p "$1"
  if [ ! -f "$1/cert.pem" ]; then
    openssl req -x509 -newkey rsa:3072 -sha256 -days 825 -nodes -keyout "$1/key.pem" -out "$1/cert.pem" \
      -subj "/C=FR/O=RedOne/OU=DSI/CN=$2" -addext "subjectAltName=$3" 2>/dev/null
  fi
  chmod 640 "$1/key.pem"
  openssl x509 -in "$1/cert.pem" -noout -subject -enddate | tr '\n' ' '; echo
}

if [ "$ROLE" = grafana ]; then
  cert /etc/grafana/tls grafana.redone.local "DNS:grafana.redone.local,DNS:srv-supervision.redone.local,IP:192.168.100.204,IP:10.2.1.3"
  chown -R root:grafana /etc/grafana/tls
  python3 - <<'PY'
import re
p = '/etc/grafana/grafana.ini'; s = open(p).read()
def setk(section, key, val):
    global s
    m = re.search(r'^\[' + re.escape(section) + r'\]\s*$', s, re.M)
    start = m.end(); nxt = re.search(r'^\[', s[start:], re.M); end = start + (nxt.start() if nxt else len(s) - start)
    body = s[start:end]
    pat = re.compile(r'^[;#]?\s*' + re.escape(key) + r'\s*=.*$', re.M)
    if pat.search(body): body = pat.sub(f'{key} = {val}', body, count=1)
    else: body = f'\n{key} = {val}' + body
    s = s[:start] + body + s[end:]
for sec, k, v in [('server', 'protocol', 'https'), ('server', 'cert_file', '/etc/grafana/tls/cert.pem'),
                  ('server', 'cert_key', '/etc/grafana/tls/key.pem'), ('server', 'root_url', 'https://192.168.100.204:3000/'),
                  ('security', 'cookie_secure', 'true'), ('security', 'cookie_samesite', 'strict'),
                  ('security', 'disable_gravatar', 'true'), ('security', 'strict_transport_security', 'true'),
                  ('analytics', 'reporting_enabled', 'false'), ('analytics', 'check_for_updates', 'false'),
                  ('analytics', 'check_for_plugin_updates', 'false'), ('analytics', 'feedback_links_enabled', 'false'),
                  ('snapshots', 'external_enabled', 'false'), ('users', 'allow_sign_up', 'false'),
                  ('auth.anonymous', 'enabled', 'false')]:
    setk(sec, k, v)
open(p, 'w').write(s)
# Source de données Zabbix : API en HTTPS
d = '/etc/grafana/provisioning/datasources/zabbix.yaml'; t = open(d).read()
t = t.replace('http://10.2.1.52/zabbix/', 'https://10.2.1.52/zabbix/')
if 'tlsSkipVerify' not in t:
    t = t.replace('jsonData:', 'jsonData:\n      tlsSkipVerify: true', 1)
open(d, 'w').write(t)
PY
  # Prometheus : durée de conservation explicite (30 jours)
  sed -i 's/^ARGS=.*/ARGS="--storage.tsdb.retention.time=30d"/' /etc/default/prometheus
  systemctl restart grafana-server prometheus
  sleep 8
  curl -sk -o /dev/null -w "Grafana HTTPS : %{http_code}\n" https://127.0.0.1:3000/login
  grep -E "url|tlsSkip" /etc/grafana/provisioning/datasources/zabbix.yaml
fi

if [ "$ROLE" = zabbix ]; then
  cert /etc/ssl/redone zabbix.redone.local "DNS:zabbix.redone.local,DNS:srv-zabbix.redone.local,IP:192.168.100.210,IP:10.2.1.52"
  chown -R root:root /etc/ssl/redone
  a2enmod -q ssl headers rewrite >/dev/null
  cat > /etc/apache2/sites-available/redone-zabbix-ssl.conf <<'EOF'
<VirtualHost *:443>
    ServerName zabbix.redone.local
    DocumentRoot /var/www/html
    SSLEngine on
    SSLCertificateFile    /etc/ssl/redone/cert.pem
    SSLCertificateKeyFile /etc/ssl/redone/key.pem
    SSLProtocol -all +TLSv1.2 +TLSv1.3
    Header always set Strict-Transport-Security "max-age=31536000"
    Header always set X-Content-Type-Options "nosniff"
</VirtualHost>
EOF
  # HTTP -> HTTPS (sauf l'agent local qui teste http://localhost)
  cat > /etc/apache2/conf-available/redone-https-redirect.conf <<'EOF'
RewriteEngine On
RewriteCond %{HTTPS} off
RewriteCond %{REMOTE_ADDR} !^127\.0\.0\.1$
RewriteRule ^/(.*)$ https://%{HTTP_HOST}/$1 [R=301,L]
EOF
  a2ensite -q redone-zabbix-ssl; a2enconf -q redone-https-redirect
  apache2ctl configtest 2>&1 | tail -1
  systemctl reload apache2
  # pare-feu : ouvrir 443
  sed -i 's#    tcp dport 80 ip saddr { $ADMIN_NET, $LAN } accept comment "Interface et API Zabbix (Grafana 10.2.1.3)"#    tcp dport { 80, 443 } ip saddr { $ADMIN_NET, $LAN } accept comment "Interface et API Zabbix, HTTP redirigé vers HTTPS"#' /etc/nftables.d/redone-firewall.nft
  nft -f /etc/nftables.d/redone-firewall.nft
  curl -sk -o /dev/null -w "Zabbix HTTPS : %{http_code}\n" https://127.0.0.1/zabbix/index.php
fi

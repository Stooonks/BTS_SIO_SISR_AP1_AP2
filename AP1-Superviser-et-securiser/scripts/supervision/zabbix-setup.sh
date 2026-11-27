#!/bin/bash
# Installation du serveur Zabbix 7.0 LTS (paquets Debian) - SRV-ZABBIX (RedOne)
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -q postgresql zabbix-server-pgsql zabbix-frontend-php php-pgsql apache2 libapache2-mod-php zabbix-agent2 >/dev/null
ACCES=/root/zabbix-acces.txt
umask 077
gen() { openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | cut -c1-20; }

# --- Base PostgreSQL ---
if ! sudo -u postgres psql -tAc "select 1 from pg_roles where rolname='zabbix'" | grep -q 1; then
  DBPASS=$(gen)
  sudo -u postgres psql -qc "create role zabbix login password '$DBPASS'"
  sudo -u postgres createdb -O zabbix -E UTF8 -T template0 zabbix
  for f in schema images data; do zcat /usr/share/zabbix-server-pgsql/$f.sql.gz | sudo -u zabbix psql -q zabbix >/dev/null; done
  echo "DB_PASSWORD=$DBPASS" > /root/.zabbix-db
fi
. /root/.zabbix-db

# --- Serveur Zabbix ---
cat > /etc/zabbix/zabbix_server.conf.d/redone.conf <<CONF
DBHost=localhost
DBName=zabbix
DBUser=zabbix
DBPassword=$DB_PASSWORD
StartPollers=10
CacheSize=64M
Timeout=10
CONF
chown root:zabbix /etc/zabbix/zabbix_server.conf.d/redone.conf; chmod 640 /etc/zabbix/zabbix_server.conf.d/redone.conf
grep -q '^Include=/etc/zabbix/zabbix_server.conf.d' /etc/zabbix/zabbix_server.conf || echo 'Include=/etc/zabbix/zabbix_server.conf.d/*.conf' >> /etc/zabbix/zabbix_server.conf

# --- Interface web ---
WEBCONF=/etc/zabbix/zabbix.conf.php   # chemin attendu par le paquet Debian (CConfigFile::CONFIG_FILE_PATH)
# Interface en français : la locale doit exister sur le système
apt-get install -y -q locales >/dev/null
sed -i 's/^# *fr_FR.UTF-8 UTF-8/fr_FR.UTF-8 UTF-8/' /etc/locale.gen && locale-gen >/dev/null
cat > "$WEBCONF" <<PHP
<?php
\$DB['TYPE']     = 'POSTGRESQL';
\$DB['SERVER']   = 'localhost';
\$DB['PORT']     = '0';
\$DB['DATABASE'] = 'zabbix';
\$DB['USER']     = 'zabbix';
\$DB['PASSWORD'] = '$DB_PASSWORD';
\$DB['SCHEMA']   = '';
\$DB['ENCRYPTION'] = false;
\$ZBX_SERVER      = 'localhost';
\$ZBX_SERVER_PORT = '10051';
\$ZBX_SERVER_NAME = 'RedOne - Zabbix';
\$IMAGE_FORMAT_DEFAULT = IMAGE_FORMAT_PNG;
PHP
chown root:www-data "$WEBCONF"; chmod 640 "$WEBCONF"
PHPV=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
cat > /etc/php/$PHPV/apache2/conf.d/99-zabbix.ini <<INI
max_execution_time = 300
max_input_time = 300
post_max_size = 16M
memory_limit = 256M
date.timezone = Europe/Paris
INI
a2enconf -q zabbix-frontend-php
# Page d'accueil du serveur web -> Zabbix
echo '<meta http-equiv="refresh" content="0; url=/zabbix/">' > /var/www/html/index.html
# Ne pas afficher la version d'Apache
sed -i 's/^ServerTokens .*/ServerTokens Prod/; s/^ServerSignature .*/ServerSignature Off/' /etc/apache2/conf-available/security.conf

# --- Agent local ---
sed -i "s/^Hostname=.*/Hostname=SRV-ZABBIX/" /etc/zabbix/zabbix_agent2.conf
: <<CONF
Server=127.0.0.1
ServerActive=127.0.0.1
Hostname=SRV-ZABBIX
CONF

systemctl enable -q zabbix-server zabbix-agent2 apache2 postgresql
systemctl restart zabbix-server zabbix-agent2 apache2
sleep 5
systemctl is-active zabbix-server zabbix-agent2 apache2 postgresql
tail -3 /var/log/zabbix-server/zabbix_server.log
curl -s -o /dev/null -w "frontend HTTP %{http_code}\n" http://localhost/zabbix/index.php

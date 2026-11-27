#!/bin/bash
# Installation GLPI 12.0.2 - SRV-GLPI (RedOne)
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
VER=12.0.2

apt-get install -y -qq apache2 mariadb-server \
  php libapache2-mod-php php-mysql php-curl php-gd php-intl php-ldap php-xml \
  php-mbstring php-zip php-bz2 php-bcmath php-opcache php-apcu >/dev/null

# --- Base de donnees
DBPASS=$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)
mysql -e "CREATE DATABASE IF NOT EXISTS glpi CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER IF NOT EXISTS 'glpi'@'localhost' IDENTIFIED BY '${DBPASS}'; ALTER USER 'glpi'@'localhost' IDENTIFIED BY '${DBPASS}';"
mysql -e "GRANT ALL PRIVILEGES ON glpi.* TO 'glpi'@'localhost'; FLUSH PRIVILEGES;"
(mysql_tzinfo_to_sql /usr/share/zoneinfo 2>/dev/null | mysql mysql) || true
mysql -e "GRANT SELECT ON mysql.time_zone_name TO 'glpi'@'localhost'; FLUSH PRIVILEGES;"

# --- Fichiers GLPI (arborescence securisee : config, data et logs hors racine web)
rm -rf /var/www/glpi
tar -xzf /tmp/glpi.tgz -C /var/www/
mkdir -p /etc/glpi /var/lib/glpi /var/log/glpi
cp -a /var/www/glpi/config/. /etc/glpi/ 2>/dev/null || true
cp -a /var/www/glpi/files/. /var/lib/glpi/ 2>/dev/null || true
rm -rf /var/www/glpi/config /var/www/glpi/files
cat > /var/www/glpi/inc/downstream.php <<'PHP'
<?php
define('GLPI_CONFIG_DIR', '/etc/glpi/');
if (file_exists(GLPI_CONFIG_DIR . '/local_define.php')) {
    require_once GLPI_CONFIG_DIR . '/local_define.php';
}
PHP
cat > /etc/glpi/local_define.php <<'PHP'
<?php
define('GLPI_VAR_DIR', '/var/lib/glpi');
define('GLPI_LOG_DIR', '/var/log/glpi');
PHP
chown -R root:root /var/www/glpi
chown -R www-data:www-data /etc/glpi /var/lib/glpi /var/log/glpi
chmod 750 /etc/glpi /var/lib/glpi /var/log/glpi

# --- PHP
PHPV=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
cat > /etc/php/$PHPV/apache2/conf.d/99-glpi.ini <<'INI'
session.cookie_httponly = On
session.cookie_samesite = Lax
memory_limit = 256M
upload_max_filesize = 20M
post_max_size = 25M
max_execution_time = 600
date.timezone = Europe/Paris
INI
cp /etc/php/$PHPV/apache2/conf.d/99-glpi.ini /etc/php/$PHPV/cli/conf.d/99-glpi.ini

# --- Apache : racine web sur /public
cat > /etc/apache2/sites-available/glpi.conf <<'APACHE'
<VirtualHost *:80>
    ServerName glpi.redone.local
    DocumentRoot /var/www/glpi/public
    <Directory /var/www/glpi/public>
        Require all granted
        RewriteEngine On
        RewriteCond %{HTTP:Authorization} ^(.+)$
        RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteRule ^(.*)$ index.php [QSA,L]
    </Directory>
    ErrorLog ${APACHE_LOG_DIR}/glpi_error.log
    CustomLog ${APACHE_LOG_DIR}/glpi_access.log combined
</VirtualHost>
APACHE
sed -i 's/^ServerTokens .*/ServerTokens Prod/; s/^ServerSignature .*/ServerSignature Off/' /etc/apache2/conf-available/security.conf
a2enmod -q rewrite >/dev/null
a2dissite -q 000-default >/dev/null
a2ensite -q glpi >/dev/null
systemctl restart apache2

# --- Installation de la base GLPI
cd /var/www/glpi
sudo -u www-data php bin/console db:install -L fr_FR -H localhost -d glpi -u glpi -p "${DBPASS}" --no-interaction --no-telemetry
unset DBPASS

# --- Durcissement post-installation
rm -f /var/www/glpi/install/install.php

# --- Taches automatiques
echo '* * * * * www-data /usr/bin/php /var/www/glpi/front/cron.php >/dev/null 2>&1' > /etc/cron.d/glpi
chmod 644 /etc/cron.d/glpi

echo "INSTALL_OK"

#!/bin/bash
# Installe le certificat signé par l'autorité RedOne-AC-Racine (AD CS, SRV-AD) à la place du certificat auto-signé.
# Usage (root) : pki-installer-certificat.sh <grafana|glpi|zabbix|wazuh> <nom>
#   /root/redone-pki/<nom>.key  clé privée générée sur le serveur (ne le quitte jamais)
#   /root/redone-pki/<nom>.crt  certificat délivré par l'autorité
#   /root/redone-pki/RedOne-AC-Racine.crt  certificat de l'autorité racine
set -euo pipefail
SVC=$1; N=$2; D=/root/redone-pki
KEY=$D/$N.key; CRT=$D/$N.crt; CA=$D/RedOne-AC-Racine.crt

# Contrôles : le certificat correspond à la clé et est bien signé par l'autorité RedOne
[ "$(openssl x509 -noout -pubkey -in "$CRT" | sha256sum)" = "$(openssl pkey -pubout -in "$KEY" | sha256sum)" ] || { echo "certificat et clé ne correspondent pas"; exit 1; }
openssl verify -CAfile "$CA" "$CRT"

# L'autorité racine devient de confiance pour le système (curl, API Zabbix de Grafana…)
install -m 644 "$CA" /usr/local/share/ca-certificates/RedOne-AC-Racine.crt
update-ca-certificates >/dev/null
CHAINE=$(mktemp); cat "$CRT" "$CA" > "$CHAINE"

remplace() { # fichier_cible source propriétaire mode
  [ -f "$1" ] && [ ! -f "$1.autosigne" ] && cp -a "$1" "$1.autosigne"
  install -o "$3" -g "$3" -m "$4" "$2" "$1"
}
case "$SVC" in
  grafana) remplace /etc/grafana/tls/cert.pem "$CHAINE" grafana 640; remplace /etc/grafana/tls/key.pem "$KEY" grafana 640
           systemctl restart grafana-server ;;
  glpi)    remplace /etc/ssl/certs/glpi.crt "$CHAINE" root 644; remplace /etc/ssl/private/glpi.key "$KEY" root 600
           apache2ctl configtest && systemctl reload apache2 ;;
  zabbix)  remplace /etc/ssl/redone/cert.pem "$CHAINE" root 644; remplace /etc/ssl/redone/key.pem "$KEY" root 600
           apache2ctl configtest && systemctl reload apache2 ;;
  wazuh)   remplace /etc/wazuh-dashboard/certs/wazuh-dashboard.pem "$CHAINE" wazuh-dashboard 400
           remplace /etc/wazuh-dashboard/certs/wazuh-dashboard-key.pem "$KEY" wazuh-dashboard 400
           systemctl restart wazuh-dashboard ;;
  *) echo "service inconnu"; exit 1 ;;
esac
rm -f "$CHAINE"
echo "$SVC : certificat RedOne-AC-Racine installé (ancien certificat conservé en .autosigne)"

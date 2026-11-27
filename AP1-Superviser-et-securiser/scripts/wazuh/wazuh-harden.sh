#!/bin/bash
# Durcissement et configuration Wazuh - SRV-WAZUH (RedOne)
set -euo pipefail
CONF=/var/ossec/etc/ossec.conf
cp -a "$CONF" /root/ossec.conf.orig.$(date +%Y%m%d%H%M)

# 1. Archive des identifiants generee par l'installateur : hors de /tmp, root uniquement
if [ -f /tmp/wazuh-install-files.tar ]; then
  mv /tmp/wazuh-install-files.tar /root/wazuh-install-files.tar
  chmod 600 /root/wazuh-install-files.tar
fi

# 2. Enrolement des agents protege par mot de passe
if [ ! -s /var/ossec/etc/authd.pass ]; then
  openssl rand -base64 24 | tr -d '/+=' | head -c 24 > /var/ossec/etc/authd.pass
fi
chown root:wazuh /var/ossec/etc/authd.pass
chmod 640 /var/ossec/etc/authd.pass
sed -i 's#<use_password>no</use_password>#<use_password>yes</use_password>#' "$CONF"

# 3. FIM temps reel sur les fichiers sensibles + zone de donnees RedOne
mkdir -p /srv/redone/donnees-sensibles
echo "Fichier de reference - donnees confidentielles RedOne (demo FIM)" > /srv/redone/donnees-sensibles/bdpharma-extrait.csv
if ! grep -q "/srv/redone" "$CONF"; then
  sed -i '0,/<directories>\/bin,\/sbin,\/boot<\/directories>/s##<directories>/bin,/sbin,/boot</directories>\n    <!-- RedOne : surveillance temps reel -->\n    <directories realtime="yes" check_all="yes" report_changes="yes">/etc/ssh,/etc/sudoers.d,/etc/passwd,/etc/group</directories>\n    <directories realtime="yes" check_all="yes" report_changes="yes">/srv/redone</directories>#' "$CONF"
fi

# 4. Reponse active : blocage IP apres brute force SSH (regle 5763), 10 min
#    Le poste d'administration est en liste blanche pour ne pas se bloquer soi-meme
if ! grep -q "redone-ssh-bruteforce" "$CONF"; then
  sed -i '0,/<\/ossec_config>/s##  <!-- redone-ssh-bruteforce -->\n  <active-response>\n    <command>firewall-drop</command>\n    <location>local</location>\n    <rules_id>5763</rules_id>\n    <timeout>600</timeout>\n  </active-response>\n</ossec_config>#' "$CONF"
  sed -i '0,/<white_list>::1<\/white_list>/s##<white_list>::1</white_list>\n    <white_list>192.168.100.141</white_list>#' "$CONF"
fi

/var/ossec/bin/wazuh-logtest -V >/dev/null 2>&1 || true
systemctl restart wazuh-manager
sleep 15
systemctl is-active wazuh-manager
grep -n "use_password\|/srv/redone\|redone-ssh\|192.168.100.141" "$CONF" | cut -c1-120
echo HARDEN_OK

#!/bin/bash
# RGPD sur SRV-WAZUH : durée de conservation des alertes (180 jours) et minimisation du FIM
set -euo pipefail
JOURS=180

# 1. Minimisation : le FIM ne doit pas copier le CONTENU des fichiers de données de santé (/srv/redone)
#    dans le SIEM (report_changes stocke un diff du fichier). On garde la détection (hash, droits, auteur).
sed -i 's#<directories realtime="yes" check_all="yes" report_changes="yes">/srv/redone</directories>#<directories realtime="yes" check_all="yes" report_changes="no">/srv/redone</directories>#' /var/ossec/etc/ossec.conf
for f in /var/ossec/etc/shared/*/agent.conf; do
  sed -i 's#report_changes="yes">/srv/redone#report_changes="no">/srv/redone#g' "$f"
done
rm -rf /var/ossec/queue/diff/local/srv/redone
grep -c 'report_changes="no">/srv/redone' /var/ossec/etc/ossec.conf | sed 's/^/FIM \/srv\/redone sans copie du contenu : /'

# 2. Conservation des alertes dans l'indexer : suppression automatique après $JOURS jours (politique ISM)
P=$(tar -xOf /root/wazuh-install-files.tar wazuh-install-files/wazuh-passwords.txt \
    | awk '/indexer_username: .admin./{getline; print}' | sed -E "s/.*indexer_password: ['\"]?([^'\"]+)['\"]?/\1/")
API=https://127.0.0.1:9200
POLICY=$(cat <<EOF
{"policy":{"description":"RedOne RGPD : alertes conservées ${JOURS} jours puis supprimées",
 "default_state":"conservation",
 "states":[{"name":"conservation","actions":[],"transitions":[{"state_name":"suppression","conditions":{"min_index_age":"${JOURS}d"}}]},
           {"name":"suppression","actions":[{"delete":{}}],"transitions":[]}],
 "ism_template":[{"index_patterns":["wazuh-alerts-*","wazuh-archives-*"],"priority":100}]}}
EOF
)
curl -sk -u "admin:$P" -X DELETE "$API/_plugins/_ism/policies/redone-retention" >/dev/null || true
curl -sk -u "admin:$P" -H 'Content-Type: application/json' -X PUT "$API/_plugins/_ism/policies/redone-retention" -d "$POLICY" \
  | grep -o '"_id":"[^"]*"' | sed 's/^/politique ISM : /'
curl -sk -u "admin:$P" -H 'Content-Type: application/json' -X POST "$API/_plugins/_ism/add/wazuh-alerts-*,wazuh-archives-*" \
  -d '{"policy_id":"redone-retention"}' | grep -o '"updated_indices":[0-9]*' | sed 's/^/index existants rattachés : /'

# 3. Conservation des fichiers d'alertes sur le manager (journaux bruts)
cat > /etc/cron.daily/redone-wazuh-retention <<EOF
#!/bin/sh
# RGPD : suppression des journaux d'alertes Wazuh de plus de ${JOURS} jours
find /var/ossec/logs/alerts /var/ossec/logs/archives -type f -mtime +${JOURS} -delete
EOF
chmod 755 /etc/cron.daily/redone-wazuh-retention
echo "purge quotidienne des fichiers > ${JOURS} jours : /etc/cron.daily/redone-wazuh-retention"

systemctl restart wazuh-manager
sleep 5; systemctl is-active wazuh-manager

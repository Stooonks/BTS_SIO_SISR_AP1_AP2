cat > /etc/issue.net <<'B'
*********************************************************************************
  RedOne - Systeme d'information a usage professionnel.
  Acces reserve aux personnes autorisees. Les connexions et les actions sont
  journalisees et supervisees (Wazuh, Zabbix) et conservees de 90 jours a 1 an
  conformement a la charte informatique et au RGPD. Contact : dpo@redone.com
*********************************************************************************
B
if grep -q "^Banner" /etc/ssh/sshd_config; then sed -i 's#^Banner.*#Banner /etc/issue.net#' /etc/ssh/sshd_config
elif [ -d /etc/ssh/sshd_config.d ] && grep -rq "^Banner" /etc/ssh/sshd_config.d/; then sed -i 's#^Banner.*#Banner /etc/issue.net#' $(grep -rl "^Banner" /etc/ssh/sshd_config.d/)
else echo "Banner /etc/issue.net" > /etc/ssh/sshd_config.d/10-redone-banner.conf; fi
sshd -t && systemctl reload ssh && echo "$(hostname) : bannière SSH OK"

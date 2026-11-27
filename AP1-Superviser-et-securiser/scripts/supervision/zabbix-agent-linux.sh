#!/bin/bash
# Agent Zabbix 2 (paquet Debian) - usage : zabbix-agent-linux.sh NOM_HOTE
set -eu
export DEBIAN_FRONTEND=noninteractive
apt-get install -y -q zabbix-agent2 >/dev/null
C=/etc/zabbix/zabbix_agent2.conf
sed -i "s/^Server=.*/Server=10.2.1.52/; s/^ServerActive=.*/ServerActive=10.2.1.52/; s/^Hostname=.*/Hostname=$1/" $C
systemctl enable -q zabbix-agent2; systemctl restart zabbix-agent2
# Pare-feu : n'autoriser le port 10050 que depuis le serveur Zabbix
if command -v nft >/dev/null && nft list chain inet filter input >/dev/null 2>&1; then
  nft list chain inet filter input | grep -q 'dport 10050' || nft insert rule inet filter input ip saddr 10.2.1.52 tcp dport 10050 accept
fi
if command -v ufw >/dev/null && ufw status | grep -q active; then ufw allow from 10.2.1.52 to any port 10050 proto tcp >/dev/null; fi
sleep 2; echo "$1 : $(systemctl is-active zabbix-agent2) $(zabbix_agent2 -V | head -1)"

#!/bin/bash
# Pare-feu nftables des serveurs Linux RedOne (entrées filtrées, sorties libres)
# Usage : linux-firewall.sh <supervision|glpi|wazuh|zabbix>   (en root)
# Sécurité : retour arrière automatique au bout de 3 min tant que l'accès n'est pas confirmé
#            (systemctl stop redone-fw-rollback.timer pour confirmer)
set -euo pipefail
ROLE=$1
F=/etc/nftables.d/redone-firewall.nft
mkdir -p /etc/nftables.d

case "$ROLE" in
  supervision) SPECIFIQUE='    tcp dport 3000 ip saddr { $ADMIN_NET, $LAN } accept comment "Grafana"
    udp dport { 5514, 5515 } ip saddr $LAN accept comment "Alloy : syslog Wazuh et Veeam"' ;;
  glpi) SPECIFIQUE='    tcp dport { 80, 443 } ip saddr { $ADMIN_NET, $LAN } accept comment "GLPI (web)"' ;;
  wazuh) SPECIFIQUE='    tcp dport 443 ip saddr { $ADMIN_NET, $LAN } accept comment "Dashboard Wazuh"
    tcp dport { 1514, 1515 } ip saddr $LAN accept comment "Agents Wazuh : envoi et enrôlement"' ;;
  zabbix) SPECIFIQUE='    tcp dport 80 ip saddr { $ADMIN_NET, $LAN } accept comment "Interface et API Zabbix (Grafana 10.2.1.3)"
    tcp dport 10051 ip saddr $LAN accept comment "Zabbix trapper et checks actifs"' ;;
  *) echo "rôle inconnu"; exit 1 ;;
esac

{
cat <<'EOF'
# RedOne - pare-feu du serveur - généré par linux-firewall.sh
define ADMIN_PC   = 192.168.100.141   # poste d'administration
define PROXMOX    = 192.168.100.2
define ADMIN_NET  = 192.168.100.0/24  # réseau de la salle (interfaces web)
define LAN        = 10.2.1.0/24       # VLAN 200 RedOne
define ZABBIX     = 10.2.1.52
define PROMETHEUS = 10.2.1.3

table inet redone_fw
delete table inet redone_fw
table inet redone_fw {
  chain input {
    type filter hook input priority filter; policy drop;
    iif lo accept
    ct state established,related accept
    ct state invalid drop
    ip protocol icmp icmp type { echo-request, destination-unreachable, time-exceeded } limit rate 20/second accept
    ip6 nexthdr icmpv6 accept
    tcp dport 22 ip saddr { $ADMIN_PC, $PROXMOX, $LAN } accept comment "SSH administration"
    tcp dport 10050 ip saddr $ZABBIX accept comment "Agent Zabbix"
    tcp dport 9100 ip saddr $PROMETHEUS accept comment "node_exporter (Prometheus)"
EOF
echo "$SPECIFIQUE"
cat <<'EOF'
    limit rate 5/minute log prefix "nft-redone-drop: " level info
  }
}
EOF
} > "$F"
nft -c -f "$F"

cat > /etc/systemd/system/redone-firewall.service <<'EOF'
[Unit]
Description=RedOne - pare-feu nftables (entrées)
Wants=network-pre.target
Before=network-pre.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/nft -f /etc/nftables.d/redone-firewall.nft
ExecStop=/usr/sbin/nft delete table inet redone_fw

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload

# Services de découverte inutiles sur un serveur (LLMNR / mDNS)
mkdir -p /etc/systemd/resolved.conf.d
printf '[Resolve]\nLLMNR=no\nMulticastDNS=no\n' > /etc/systemd/resolved.conf.d/redone.conf
systemctl restart systemd-resolved 2>/dev/null || true
systemctl disable --now avahi-daemon.socket avahi-daemon.service >/dev/null 2>&1 || true

# Filet de sécurité : suppression des règles dans 3 min sauf confirmation
systemctl stop redone-fw-rollback.timer >/dev/null 2>&1 || true
systemd-run --unit=redone-fw-rollback --on-active=180 /usr/sbin/nft delete table inet redone_fw >/dev/null
nft -f "$F"
echo "pare-feu appliqué ($ROLE) - retour arrière dans 3 min sauf : systemctl stop redone-fw-rollback.timer"

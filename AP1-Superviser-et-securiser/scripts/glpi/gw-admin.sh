#!/bin/bash
# SRV-GLPI : passerelle d'administration restreinte vers le VLAN 200 (10.2.1.0/24)
# Seul le poste d'administration 192.168.100.141 peut traverser ; NAT pour le retour.
set -euo pipefail
echo 'net.ipv4.ip_forward = 1' > /etc/sysctl.d/70-redone-gw-admin.conf
sysctl -q -p /etc/sysctl.d/70-redone-gw-admin.conf

mkdir -p /etc/nftables.d
cat > /etc/nftables.d/redone-gw-admin.nft <<'NFT'
table ip redone_gw {
  chain forward {
    type filter hook forward priority 0; policy drop;
    ct state established,related accept
    iifname "eth0" oifname "eth1" ip saddr 192.168.100.141 ip daddr 10.2.1.0/24 accept
  }
  chain postrouting {
    type nat hook postrouting priority srcnat; policy accept;
    oifname "eth1" ip saddr 192.168.100.141 masquerade
  }
}
NFT
nft -c -f /etc/nftables.d/redone-gw-admin.nft
nft list table ip redone_gw >/dev/null 2>&1 && nft delete table ip redone_gw
nft -f /etc/nftables.d/redone-gw-admin.nft

# Chargement au démarrage (sans toucher aux autres règles)
cat > /etc/systemd/system/redone-gw-admin.service <<'UNIT'
[Unit]
Description=RedOne - passerelle d'administration vers le VLAN 200
After=network-online.target
Wants=network-online.target
[Service]
Type=oneshot
ExecStartPre=-/usr/sbin/nft delete table ip redone_gw
ExecStart=/usr/sbin/nft -f /etc/nftables.d/redone-gw-admin.nft
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable redone-gw-admin.service >/dev/null 2>&1
sysctl -n net.ipv4.ip_forward
nft list table ip redone_gw | grep -E "accept|masquerade|policy"
echo GW_OK

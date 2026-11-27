#!/bin/bash
# SRV-WAZUH (manager) : déclare la réponse active « redone-nft-drop »
# Déclencheurs : force brute SSH (5712 utilisateur inexistant, 5720 échecs multiples, 5763 authentification échouée)
# Usage : sudo bash wazuh-active-response.sh   (le script redone-nft-drop doit déjà être sur les agents)
set -euo pipefail
C=/var/ossec/etc/ossec.conf
cp -a "$C" "$C.avant-ar-$(date +%Y%m%d-%H%M%S)"

# 1. Supprime l'ancienne réponse firewall-drop (iptables absent sur les serveurs : elle ne faisait rien)
python3 - "$C" <<'EOF'
import re, sys
p = sys.argv[1]; s = open(p, encoding="utf-8").read()
s = re.sub(r"\n  <active-response>\s*<command>firewall-drop</command>.*?</active-response>\n", "\n", s, flags=re.S)
s = re.sub(r"\n<ossec_config>\s*<!-- RedOne : réponse active -->.*?</ossec_config>\n", "\n", s, flags=re.S)
# Adresses jamais bloquées : poste d'administration, Proxmox, Wazuh, passerelle
for ip in ["192.168.100.2", "192.168.100.209", "10.2.1.51", "10.2.1.1"]:
    if f"<white_list>{ip}</white_list>" not in s:
        s = s.replace("<white_list>192.168.100.141</white_list>",
                      f"<white_list>192.168.100.141</white_list>\n    <white_list>{ip}</white_list>", 1)
s += """
<ossec_config>
  <!-- RedOne : réponse active -->
  <command>
    <name>redone-nft-drop</name>
    <executable>redone-nft-drop</executable>
  </command>
  <active-response>
    <disabled>no</disabled>
    <command>redone-nft-drop</command>
    <location>local</location>
    <rules_id>5712,5720,5763</rules_id>
  </active-response>
</ossec_config>
"""
open(p, "w", encoding="utf-8").write(s)
EOF
/var/ossec/bin/wazuh-analysisd -t
systemctl restart wazuh-manager
echo "réponse active redone-nft-drop déclarée (règles 5712, 5720, 5763)"

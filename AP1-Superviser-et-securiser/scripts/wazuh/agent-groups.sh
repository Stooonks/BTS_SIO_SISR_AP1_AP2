#!/bin/bash
# Groupes d'agents Wazuh RedOne + configuration centralisée
set -euo pipefail
B=/var/ossec/bin/agent_groups
for g in linux-serveurs windows-ad; do
  $B -l -q 2>/dev/null | grep -qx "$g" || $B -a -g "$g" -q
done

cat > /var/ossec/etc/shared/linux-serveurs/agent.conf <<'XML'
<agent_config os="Linux">
  <!-- Serveurs Linux RedOne (GLPI, supervision...) -->
  <syscheck>
    <frequency>21600</frequency>
    <directories realtime="yes" check_all="yes" report_changes="yes">/etc/ssh,/etc/sudoers.d,/etc/passwd,/etc/group,/etc/shadow</directories>
    <directories realtime="yes" check_all="yes">/etc/glpi,/etc/apache2</directories>
    <directories realtime="yes" check_all="yes" report_changes="yes">/srv/redone</directories>
  </syscheck>
  <localfile>
    <log_format>journald</log_format>
    <location>journald</location>
  </localfile>
  <localfile>
    <log_format>apache</log_format>
    <location>/var/log/apache2/glpi_access.log</location>
  </localfile>
  <localfile>
    <log_format>apache</log_format>
    <location>/var/log/apache2/glpi_error.log</location>
  </localfile>
</agent_config>
XML

cat > /var/ossec/etc/shared/windows-ad/agent.conf <<'XML'
<agent_config os="Windows">
  <!-- Contrôleurs de domaine RedOne -->
  <localfile>
    <location>Security</location>
    <log_format>eventchannel</log_format>
  </localfile>
  <localfile>
    <location>Directory Service</location>
    <log_format>eventchannel</log_format>
  </localfile>
  <localfile>
    <location>Microsoft-Windows-Windows Defender/Operational</location>
    <log_format>eventchannel</log_format>
  </localfile>
  <syscheck>
    <frequency>21600</frequency>
    <directories realtime="yes" check_all="yes">C:\Windows\SYSVOL\domain\Policies</directories>
    <windows_registry arch="both">HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services</windows_registry>
    <windows_registry arch="both">HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Run</windows_registry>
  </syscheck>
</agent_config>
XML

chown wazuh:wazuh /var/ossec/etc/shared/*/agent.conf
chmod 660 /var/ossec/etc/shared/*/agent.conf
/var/ossec/bin/verify-agent-conf 2>&1 | tail -4
systemctl restart wazuh-manager
sleep 15
systemctl is-active wazuh-manager
$B -l

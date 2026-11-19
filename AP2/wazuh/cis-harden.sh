#!/bin/bash
# Durcissement SRV-WAZUH (recommandations CIS Debian 13 / ANSSI) - sans risque de perte d'accès
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Bannière légale
cat > /etc/issue.net <<'TXT'
Accès réservé au personnel autorisé de RedOne. Toute connexion est journalisée et surveillée.
TXT
cp /etc/issue.net /etc/issue

# SSH : drop-in validé avant rechargement (authentification par clé conservée)
cat > /etc/ssh/sshd_config.d/99-redone.conf <<'SSH'
PermitRootLogin no
PasswordAuthentication no
PermitEmptyPasswords no
KbdInteractiveAuthentication no
HostbasedAuthentication no
IgnoreRhosts yes
X11Forwarding no
AllowTcpForwarding no
MaxAuthTries 4
MaxSessions 10
MaxStartups 10:30:60
LoginGraceTime 60
ClientAliveInterval 300
ClientAliveCountMax 3
LogLevel VERBOSE
Banner /etc/issue.net
AllowUsers sysadmin
SSH
chmod 600 /etc/ssh/sshd_config.d/99-redone.conf
sshd -t
systemctl reload ssh

# Noyau / réseau
cat > /etc/sysctl.d/60-redone-cis.conf <<'SYS'
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0
kernel.randomize_va_space = 2
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
fs.suid_dumpable = 0
SYS
sysctl --system >/dev/null

# Pas de core dumps
echo '* hard core 0' > /etc/security/limits.d/60-redone-core.conf

# Journalisation d'audit du noyau
apt-get install -y -qq auditd audispd-plugins >/dev/null
cat > /etc/audit/rules.d/60-redone.rules <<'AUD'
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k scope
-w /etc/sudoers.d/ -p wa -k scope
-w /etc/ssh/sshd_config -p wa -k sshd
-w /var/log/sudo.log -p wa -k actions
-a always,exit -F arch=b64 -S execve -F euid=0 -F auid>=1000 -F auid!=unset -k root_cmd
AUD
augenrules --load >/dev/null 2>&1 || true
systemctl enable --now auditd >/dev/null 2>&1

# Mots de passe : durée de vie des comptes (nouveaux comptes)
sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS\t365/; s/^PASS_MIN_DAYS.*/PASS_MIN_DAYS\t1/; s/^PASS_WARN_AGE.*/PASS_WARN_AGE\t7/' /etc/login.defs

# Permissions cron
chmod 600 /etc/crontab 2>/dev/null || true
chmod 700 /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly 2>/dev/null || true

echo CIS_OK

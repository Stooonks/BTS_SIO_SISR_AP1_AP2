# Agent Zabbix 2 pour les machines Windows de RedOne (serveur Zabbix : SRV-ZABBIX 10.2.1.52)
# A lancer dans PowerShell EN ADMINISTRATEUR sur chaque machine Windows du domaine :
#   powershell -ExecutionPolicy Bypass -File \\RedOne.local\NETLOGON\zabbix-agent.ps1
$ErrorActionPreference = 'Stop'
$ver = '7.0.22'
$msi = "$env:TEMP\zabbix_agent2-$ver.msi"
$url = "https://cdn.zabbix.com/zabbix/binaries/stable/7.0/$ver/zabbix_agent2-$ver-windows-amd64-openssl.msi"

# Nom de l'hôte tel que déclaré dans Zabbix
$nom = switch ($env:COMPUTERNAME) { 'REDONE' { 'SRV-AD' } default { $env:COMPUTERNAME } }

# 1. Téléchargement depuis le site officiel de Zabbix et vérification de la signature
[Net.ServicePointManager]::SecurityProtocol = 'Tls12'
Write-Host "Téléchargement de l'agent Zabbix $ver..."
Invoke-WebRequest -Uri $url -OutFile $msi -UseBasicParsing
$sig = Get-AuthenticodeSignature $msi
Write-Host ("Signature : {0} ({1})" -f $sig.Status, $sig.SignerCertificate.Subject)
if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'Zabbix') { throw 'Signature invalide : installation annulée' }

# 2. Installation silencieuse
$p = Start-Process msiexec.exe -Wait -PassThru -ArgumentList "/i `"$msi`" /qn /l*v `"$env:TEMP\zabbix-install.log`" SERVER=10.2.1.52 SERVERACTIVE=10.2.1.52 HOSTNAME=$nom ENABLEPATH=1"
Remove-Item $msi -Force
if ($p.ExitCode -ne 0) { throw "Echec de msiexec (code $($p.ExitCode)), voir $env:TEMP\zabbix-install.log" }

# 3. Pare-feu : seul le serveur Zabbix peut interroger l'agent et pinger la machine
if (-not (Get-NetFirewallRule -DisplayName 'Zabbix Agent 2 (10050)' -ErrorAction SilentlyContinue)) {
  New-NetFirewallRule -DisplayName 'Zabbix Agent 2 (10050)' -Direction Inbound -Protocol TCP -LocalPort 10050 -RemoteAddress 10.2.1.52 -Action Allow | Out-Null }
if (-not (Get-NetFirewallRule -DisplayName 'Zabbix - ping (ICMPv4)' -ErrorAction SilentlyContinue)) {
  New-NetFirewallRule -DisplayName 'Zabbix - ping (ICMPv4)' -Direction Inbound -Protocol ICMPv4 -IcmpType 8 -RemoteAddress 10.2.1.52 -Action Allow | Out-Null }

$s = Get-Service 'Zabbix Agent 2'
Write-Host ("OK - {0} : service {1}, démarrage {2}" -f $nom, $s.Status, $s.StartType) -ForegroundColor Green

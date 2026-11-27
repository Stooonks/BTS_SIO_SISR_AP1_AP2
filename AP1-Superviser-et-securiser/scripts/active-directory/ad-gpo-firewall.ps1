# GPO « RedOne - Pare-feu Windows » et « RedOne - Exclusions antivirus » (liées au domaine)
$ErrorActionPreference = 'Stop'
Import-Module GroupPolicy, ActiveDirectory
function SetGP { for ($i = 1; $i -le 8; $i++) { try { Set-GPRegistryValue @args -ErrorAction Stop | Out-Null; return } catch { if ($i -eq 8) { throw }; Start-Sleep -Milliseconds (400 * $i) } } }
$d = Get-ADDomain; $dom = $d.DNSRoot; $dn = $d.DistinguishedName

function GPO($name, $comment) {
  $g = Get-GPO -Name $name -EA SilentlyContinue
  if (-not $g) { $g = New-GPO -Name $name -Comment $comment }
  if (-not ((Get-GPInheritance $dn).GpoLinks.DisplayName -contains $name)) { New-GPLink -Guid $g.Id -Target $dn | Out-Null }
  $g
}

# ---------- 1. Pare-feu ----------
$fw = GPO 'RedOne - Pare-feu Windows' 'Pare-feu actif sur tous les profils, entrées bloquées sauf exceptions RedOne, journal des paquets rejetés'
# Clés de stratégie du pare-feu (identiques à celles écrites par la console GPMC)
$base = 'HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall'
foreach ($prof in 'DomainProfile', 'PrivateProfile', 'PublicProfile') {
  $k = "$base\$prof"
  SetGP -Guid $fw.Id -Key $k -ValueName EnableFirewall -Type DWord -Value 1 | Out-Null
  SetGP -Guid $fw.Id -Key $k -ValueName DefaultInboundAction -Type DWord -Value 1 | Out-Null   # bloquer
  SetGP -Guid $fw.Id -Key $k -ValueName DefaultOutboundAction -Type DWord -Value 0 | Out-Null  # autoriser
  SetGP -Guid $fw.Id -Key $k -ValueName DisableNotifications -Type DWord -Value 1 | Out-Null
  SetGP -Guid $fw.Id -Key $k -ValueName AllowLocalPolicyMerge -Type DWord -Value 1 | Out-Null
  SetGP -Guid $fw.Id -Key "$k\Logging" -ValueName LogDroppedPackets -Type DWord -Value 1 | Out-Null
  SetGP -Guid $fw.Id -Key "$k\Logging" -ValueName LogFileSize -Type DWord -Value 16384 | Out-Null
  SetGP -Guid $fw.Id -Key "$k\Logging" -ValueName LogFilePath -Type ExpandString -Value '%systemroot%\system32\LogFiles\Firewall\pfirewall.log' | Out-Null
}
# Règles : format natif « v2.30|... » de la clé FirewallRules
$regles = @{
  'RedOne-Ping'   = 'v2.30|Action=Allow|Active=TRUE|Dir=In|Protocol=1|ICMP4=8:*|RA4=10.2.1.0/255.255.255.0|RA4=192.168.100.141|Name=RedOne - Ping (VLAN 200 et poste admin)|EmbedCtxt=RedOne|'
  'RedOne-Zabbix' = 'v2.30|Action=Allow|Active=TRUE|Dir=In|Protocol=6|LPort=10050|RA4=10.2.1.52|Name=RedOne - Agent Zabbix (SRV-ZABBIX)|EmbedCtxt=RedOne|'
  'RedOne-RDP'    = 'v2.30|Action=Allow|Active=TRUE|Dir=In|Protocol=6|LPort=3389|RA4=10.2.1.0/255.255.255.0|RA4=192.168.100.141|Name=RedOne - Bureau a distance (VLAN 200 et poste admin)|EmbedCtxt=RedOne|'
}
foreach ($id in $regles.Keys) { SetGP -Guid $fw.Id -Key "$base\FirewallRules" -ValueName $id -Type String -Value $regles[$id] | Out-Null }
"GPO pare-feu : 3 profils + $($regles.Count) règles"

# ---------- 2. Exclusions antivirus (Microsoft Defender) ----------
$av = GPO 'RedOne - Exclusions antivirus' 'Exclusions Defender recommandées par les éditeurs : Veeam, Wazuh, Zabbix (performances et fiabilité des sauvegardes)'
$k = 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender\Exclusions'
$chemins = 'C:\Program Files\Veeam', 'C:\ProgramData\Veeam', 'C:\Windows\Veeam', 'S:\Sauvegardes', 'C:\Scripts',
           'C:\Program Files (x86)\ossec-agent', 'C:\Program Files\Zabbix Agent 2'
$process = 'C:\Program Files\Veeam\Endpoint Backup\Veeam.EndPoint.Service.exe', 'C:\Program Files\Veeam\Endpoint Backup\VeeamAgent.exe',
           'C:\Program Files (x86)\ossec-agent\wazuh-agent.exe', 'C:\Program Files\Zabbix Agent 2\zabbix_agent2.exe'
$ext = 'vbk', 'vib', 'vbm', 'vrb', 'vsb', 'vlb'
SetGP -Guid $av.Id -Key $k -ValueName Exclusions_Paths -Type DWord -Value 1 | Out-Null
SetGP -Guid $av.Id -Key $k -ValueName Exclusions_Processes -Type DWord -Value 1 | Out-Null
SetGP -Guid $av.Id -Key $k -ValueName Exclusions_Extensions -Type DWord -Value 1 | Out-Null
foreach ($c in $chemins) { SetGP -Guid $av.Id -Key "$k\Paths" -ValueName $c -Type String -Value '0' | Out-Null }
foreach ($c in $process) { SetGP -Guid $av.Id -Key "$k\Processes" -ValueName $c -Type String -Value '0' | Out-Null }
foreach ($c in $ext) { SetGP -Guid $av.Id -Key "$k\Extensions" -ValueName $c -Type String -Value '0' | Out-Null }
"GPO exclusions : $($chemins.Count) dossiers, $($process.Count) processus, $($ext.Count) extensions"
(Get-GPInheritance $dn).GpoLinks | % { "lien : $($_.DisplayName) (activé=$($_.Enabled))" }
repadmin /syncall /AdeP | Out-Null
gpupdate /target:computer /force | Out-Null; "gpupdate SRV-AD fait"

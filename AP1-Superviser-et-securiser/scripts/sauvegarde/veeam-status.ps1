# État des sauvegardes Veeam -> Zabbix (trapper, port 10051) et Loki (syslog UDP 5515)
# Tâche planifiée SYSTEM toutes les 15 min (et à la fin de chaque sauvegarde) sur SRV-AD, SRV-AD2 et SRV-VEEAM.
# Aucun logiciel à installer : protocole Zabbix sender et syslog écrits en PowerShell.
$ZABBIX = '10.2.1.52'; $LOKI = '10.2.1.3'; $LOKI_PORT = 5515
$hote = switch ($env:COMPUTERNAME) { 'REDONE' { 'SRV-AD' } default { $env:COMPUTERNAME } }
$data = @(); $msg = @()

function Add($k, $v) { $script:data += @{ host = $hote; key = $k; value = [string]$v } }

# --- Serveur sauvegardé : résultat de la dernière sauvegarde (journal « Veeam Agent », événement 190)
if (Get-Service VeeamEndpointBackupSvc -EA SilentlyContinue) {
  $ev = Get-WinEvent -FilterHashtable @{ LogName = 'Veeam Agent'; Id = 190 } -MaxEvents 1 -EA SilentlyContinue
  if ($ev) {
    $txt = ($ev.Message -split "`n")[0]
    $res = if ($txt -match 'with Success') { 0 } elseif ($txt -match 'with Warning') { 1 } elseif ($txt -match 'with Failed|with Error') { 2 } else { 3 }
    $age = [math]::Round(((Get-Date) - $ev.TimeCreated).TotalHours, 2)
    $job = if ($txt -match "Veeam Agent '([^']+)'") { $Matches[1] } else { 'inconnu' }
  } else { $res = 3; $age = 9999; $job = 'aucune' }
  $dossier = Get-ChildItem ('\\SRV-VEEAM\Sauvegardes\' + $job) -File -EA SilentlyContinue
  $points = @($dossier | ? Extension -in '.vbk', '.vib').Count
  $taille = [math]::Round((($dossier | Measure-Object Length -Sum).Sum / 1GB), 2)
  Add 'veeam.result' $res; Add 'veeam.age_h' $age; Add 'veeam.points' $points; Add 'veeam.size_gb' $taille
  $etat = @('SUCCES', 'AVERTISSEMENT', 'ECHEC', 'AUCUNE')[$res]
  $msg += "type=sauvegarde host=$hote job=`"$job`" resultat=$etat age_h=$age points=$points taille_go=$taille"
}

# --- Serveur de sauvegarde : dépôt et copie vers le TrueNAS
if (Test-Path S:\Sauvegardes) {
  $v = Get-Volume S
  $libre = [math]::Round($v.SizeRemaining / 1GB, 1); $pct = [math]::Round(100 * $v.SizeRemaining / $v.Size, 1)
  $utilise = [math]::Round(((Get-ChildItem S:\Sauvegardes -Recurse -File | Measure-Object Length -Sum).Sum / 1GB), 2)
  $copie = Get-Content C:\Scripts\copie-truenas-historique.log -Tail 1 -EA SilentlyContinue
  $copieRes = if ($copie -match 'copie OK') { 0 } elseif ($copie) { 1 } else { 2 }
  $copieAge = if ($copie -match '^(\S+ \S+)') { [math]::Round(((Get-Date) - [datetime]$Matches[1]).TotalHours, 2) } else { 9999 }
  Add 'veeam.repo.free_gb' $libre; Add 'veeam.repo.free_pct' $pct; Add 'veeam.repo.used_gb' $utilise
  Add 'veeam.copy.result' $copieRes; Add 'veeam.copy.age_h' $copieAge
  $msg += "type=depot host=$hote libre_go=$libre libre_pct=$pct utilise_go=$utilise copie=$(@('OK','ECHEC','JAMAIS')[$copieRes]) copie_age_h=$copieAge"
}

# --- Envoi à Zabbix (protocole « sender data » : en-tête ZBXD + longueur sur 8 octets + JSON)
try {
  $json = [Text.Encoding]::UTF8.GetBytes((@{ request = 'sender data'; data = $data } | ConvertTo-Json -Compress -Depth 4))
  $paquet = [byte[]](0x5A, 0x42, 0x58, 0x44, 0x01) + [BitConverter]::GetBytes([int64]$json.Length) + $json
  $tcp = New-Object Net.Sockets.TcpClient($ZABBIX, 10051); $s = $tcp.GetStream()
  $s.Write($paquet, 0, $paquet.Length); Start-Sleep -Milliseconds 300
  $buf = New-Object byte[] 1024; $n = $s.Read($buf, 0, 1024); $tcp.Close()
  $rep = [Text.Encoding]::UTF8.GetString($buf, 13, [math]::Max(0, $n - 13))
} catch { $rep = "erreur Zabbix : $($_.Exception.Message)" }

# --- Envoi à Loki via Grafana Alloy (syslog RFC 3164, UDP)
$udp = New-Object Net.Sockets.UdpClient
foreach ($m in $msg) {
  $ligne = '<14>{0} {1} veeam: {2}' -f (Get-Date).ToString('MMM dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture).Replace(' 0', '  '), $hote, $m
  $b = [Text.Encoding]::UTF8.GetBytes($ligne); [void]$udp.Send($b, $b.Length, $LOKI, $LOKI_PORT)
}
$udp.Close()
"$(Get-Date -f 'yyyy-MM-dd HH:mm:ss') $($msg -join ' | ') => $rep" | Out-File C:\Scripts\veeam-status.log -Append -Encoding utf8
$msg; $rep

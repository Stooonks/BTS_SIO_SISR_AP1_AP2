# SRV-VEEAM : sauvegarde de la configuration du routeur Cisco R-REDONE dans le dépôt de sauvegarde
#  - connexion SSH par clé (compte svc-sauvegarde du routeur, aucun mot de passe stocké)
#  - une version est gardée seulement si la configuration a changé (historique daté), 90 jours
#  - le dossier est dans S:\Sauvegardes : il part chaque nuit sur le TrueNAS avec les sauvegardes Veeam (règle 3-2-1)
#  - résultat envoyé à Zabbix (éléments trapper de l'hôte R-REDONE) et journalisé (événements 1010 / 1011)
# Tâche planifiée « RedOne - Sauvegarde configuration routeur » : tous les jours à 3 h 30 et toutes les 4 h (SYSTEM)
$ErrorActionPreference = 'Stop'
$ROUTEUR = '192.168.100.212'
$CLE     = 'C:\Scripts\routeur\cle-sauvegarde-routeur'
$DOSSIER = 'S:\Sauvegardes\Routeur-R-REDONE'
$ZABBIX  = '10.2.1.52'
$SSH     = "$env:SystemRoot\System32\OpenSSH\ssh.exe"
$LOG     = 'C:\Scripts\routeur\sauvegarde-routeur.log'
New-Item -ItemType Directory -Force $DOSSIER | Out-Null
if (-not [Diagnostics.EventLog]::SourceExists('RedOne-Sauvegarde')) { New-EventLog -LogName Application -Source 'RedOne-Sauvegarde' }

function Envoyer-Zabbix([hashtable]$valeurs) {
  # protocole Zabbix sender (en-tête ZBXD) vers les éléments trapper de l'hôte R-REDONE
  $data = @($valeurs.GetEnumerator() | ForEach-Object { @{ host = 'R-REDONE'; key = $_.Key; value = [string]$_.Value } })
  $json = [Text.Encoding]::UTF8.GetBytes((@{ request = 'sender data'; data = $data } | ConvertTo-Json -Compress))
  $paquet = [byte[]](0x5A, 0x42, 0x58, 0x44, 0x01) + [BitConverter]::GetBytes([int64]$json.Length) + $json
  try {
    $c = New-Object Net.Sockets.TcpClient($ZABBIX, 10051); $s = $c.GetStream(); $s.Write($paquet, 0, $paquet.Length)
    $buf = New-Object byte[] 1024; $n = $s.Read($buf, 0, 1024); $c.Close()
    [Text.Encoding]::UTF8.GetString($buf, 13, [Math]::Max(0, $n - 13))
  } catch { "envoi Zabbix impossible : $($_.Exception.Message)" }
}

$horodatage = Get-Date -Format 'yyyy-MM-dd_HHmm'
$resultat = 1; $message = ''
try {
  $opts = @('-i', $CLE, '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=accept-new',
            '-o', "UserKnownHostsFile=C:\Scripts\routeur\known_hosts", '-o', 'ConnectTimeout=20',
            '-o', 'KexAlgorithms=+diffie-hellman-group14-sha1', '-o', 'HostKeyAlgorithms=+ssh-rsa',
            '-o', 'PubkeyAcceptedAlgorithms=+ssh-rsa', "svc-sauvegarde@$ROUTEUR", 'show running-config')
  # PowerShell 5.1 transforme la moindre ligne de stderr d'un programme en erreur : on l'ignore pendant l'appel
  $ErrorActionPreference = 'Continue'
  $config = (& $SSH -o LogLevel=ERROR @opts 2>$null) -join "`r`n"
  $code = $LASTEXITCODE
  $ErrorActionPreference = 'Stop'
  if ($code -ne 0 -or $config -notmatch 'hostname R-REDONE' -or $config -notmatch '(?m)^end\s*$') {
    throw "configuration incomplète ou connexion refusée (code $code)"
  }
  # comparaison sans les lignes qui changent à chaque lecture (horodatages)
  $normaliser = { param($t) (($t -split "`r?`n" | Where-Object { $_.Trim() -ne '' -and $_ -notmatch '^! (Last configuration change|NVRAM config last updated)|^Building configuration|^Current configuration' }) -join "`n").Trim() }
  $derniere = Get-ChildItem $DOSSIER -Filter 'R-REDONE_*.cfg' | Sort-Object Name | Select-Object -Last 1
  if ($derniere -and ((& $normaliser (Get-Content $derniere.FullName -Raw)) -eq (& $normaliser $config))) {
    $message = "configuration inchangée depuis $($derniere.Name)"
    (Get-Item $derniere.FullName).LastWriteTime = Get-Date
  } else {
    $fichier = Join-Path $DOSSIER "R-REDONE_$horodatage.cfg"
    Set-Content -Path $fichier -Value $config -Encoding UTF8
    $message = "nouvelle version enregistrée : $(Split-Path $fichier -Leaf) ($((Get-Item $fichier).Length) octets)"
  }
  # rétention : 90 jours, en gardant toujours au moins les 5 dernières versions
  Get-ChildItem $DOSSIER -Filter 'R-REDONE_*.cfg' | Sort-Object Name -Descending | Select-Object -Skip 5 |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-90) } | Remove-Item -Force
  $resultat = 0
  Write-EventLog -LogName Application -Source 'RedOne-Sauvegarde' -EventId 1010 -EntryType Information -Message "Sauvegarde configuration R-REDONE : $message"
} catch {
  $message = "ÉCHEC : $($_.Exception.Message)"
  Write-EventLog -LogName Application -Source 'RedOne-Sauvegarde' -EventId 1011 -EntryType Error -Message "Sauvegarde configuration R-REDONE : $message"
}
$versions = @(Get-ChildItem $DOSSIER -Filter 'R-REDONE_*.cfg').Count
$z = Envoyer-Zabbix @{ 'routeur.sauvegarde.resultat' = $resultat; 'routeur.sauvegarde.versions' = $versions; 'routeur.sauvegarde.horodatage' = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }
"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') resultat=$resultat versions=$versions $message | zabbix: $z" | Add-Content $LOG -Encoding UTF8
"resultat=$resultat versions=$versions $message"

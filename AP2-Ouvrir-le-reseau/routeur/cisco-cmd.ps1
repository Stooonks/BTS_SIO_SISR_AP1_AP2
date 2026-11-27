# Envoie des commandes IOS au routeur par le câble console et affiche les réponses.
# Usage : cisco-cmd.ps1 -Fichier commandes.txt [-Port COM4] [-Delai 20]
#   une commande par ligne, # = commentaire ; chaque commande attend le retour de l'invite (Router#, R-REDONE(config)#…)
param([Parameter(Mandatory)][string]$Fichier, [string]$Port = 'COM4', [int]$Delai = 20, [int]$Attente = 0)
$INVITE = '(?m)[\w\-\.\(\)]+[>#]\s*$'
$sp = New-Object System.IO.Ports.SerialPort $Port, 9600, 'None', 8, 'One'
$sp.Open(); Start-Sleep -Milliseconds 1000; $sp.DiscardInBuffer()

function Attendre-Invite([int]$secondes) {
  $out = ''; $fin = (Get-Date).AddSeconds($secondes)
  while ((Get-Date) -lt $fin) {
    Start-Sleep -Milliseconds 150
    if ($sp.BytesToRead -gt 0) {
      $out += $sp.ReadExisting()
      if ($out -match '--More--\s*$') { $out = $out -replace '\s*--More--\s*$', ''; $sp.Write(' '); continue }
      if ($out -match '\[confirm\]\s*$|\[yes/no\]:?\s*$|\]\?\s*$') { break }
      if ($out -match $INVITE) { Start-Sleep -Milliseconds 300; if ($sp.BytesToRead -eq 0) { break } }
    }
  }
  $out
}
try {
  # réveil : renvoie Entrée jusqu'à obtenir une invite (adaptateur USB parfois lent à démarrer)
  $ok = $false
  foreach ($i in 1..6) { $sp.Write("`r"); if ((Attendre-Invite 3) -match $INVITE) { $ok = $true; break } }
  if (-not $ok) { throw "le routeur ne répond pas sur $Port" }
  foreach ($l in Get-Content $Fichier -Encoding UTF8) {
    if ($l -match '^\s*(#|$)') { continue }
    $sp.Write($l + "`r")
    Write-Output (Attendre-Invite $Delai)
  }
} finally { $sp.Close() }

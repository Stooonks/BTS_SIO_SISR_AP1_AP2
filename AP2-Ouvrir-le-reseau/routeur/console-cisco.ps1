# Console Cisco : terminal série (équivalent PuTTY) pour le câble console du routeur
# Usage : powershell -ExecutionPolicy Bypass -File console-cisco.ps1 [-Port COM4]
# Paramètres console Cisco : 9600 bauds, 8 bits, pas de parité, 1 bit d'arrêt.
# Ctrl+] pour quitter (libère le port pour la configuration automatique).
param([string]$Port)

if (-not $Port) {
  # Préférence : adaptateur USB-série (nouveau port), sinon COM1 (port série de la carte mère)
  $usb = Get-CimInstance Win32_PnPEntity | Where-Object { $_.Name -match '\((COM\d+)\)' -and $_.Name -match 'USB|Prolific|FTDI|CH340|Silicon|Cisco' }
  $Port = if ($usb) { [regex]::Match($usb[0].Name, 'COM\d+').Value } else { 'COM1' }
}
$sp = New-Object System.IO.Ports.SerialPort $Port, 9600, 'None', 8, 'One'
$sp.Handshake = 'None'; $sp.ReadTimeout = 50; $sp.NewLine = "`r"
try { $sp.Open() } catch { Write-Host "Impossible d'ouvrir $Port : $($_.Exception.Message)" -ForegroundColor Red; exit 1 }

$Host.UI.RawUI.WindowTitle = "Console Cisco ($Port)"
Write-Host "=== Console Cisco sur $Port (9600 8N1). Appuie sur Entrée pour réveiller le routeur. Ctrl+] pour quitter. ===" -ForegroundColor Cyan
$sp.Write("`r")
try {
  while ($true) {
    if ($sp.BytesToRead -gt 0) { Write-Host -NoNewline ($sp.ReadExisting()) }
    while ([Console]::KeyAvailable) {
      $k = [Console]::ReadKey($true)
      if ($k.Key -eq [ConsoleKey]::Oem6 -and $k.Modifiers -band [ConsoleModifiers]::Control) { throw 'fin' }   # Ctrl+]
      switch ($k.Key) {
        'Enter'     { $sp.Write("`r") }
        'Backspace' { $sp.Write([char]8) }
        'Tab'       { $sp.Write("`t") }
        'UpArrow'   { $sp.Write([char]16) }   # Ctrl+P : commande précédente (IOS)
        'DownArrow' { $sp.Write([char]14) }   # Ctrl+N : commande suivante
        default     { if ($k.KeyChar -ne [char]0) { $sp.Write([string]$k.KeyChar) } }
      }
    }
    Start-Sleep -Milliseconds 20
  }
} catch { } finally { $sp.Close(); Write-Host "`n=== Console fermée, port $Port libéré ===" -ForegroundColor Cyan }

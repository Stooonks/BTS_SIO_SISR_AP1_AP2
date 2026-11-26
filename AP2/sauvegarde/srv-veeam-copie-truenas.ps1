$ErrorActionPreference='Stop'
$pw = (New-Object PSCredential 'x', (Read-Host 'Mot de passe du compte TrueNAS svc-sauvegarde' -AsSecureString)).GetNetworkCredential().Password
# Identifiant du compte de service TrueNAS, stocké pour SYSTEM (Gestionnaire d'identification)
cmdkey /add:truenas.redone.local /user:svc-sauvegarde /pass:$pw | Out-Null
$pw = $null
New-Item -ItemType Directory -Force C:\Scripts | Out-Null
$script = @'
# Copie quotidienne du dépôt Veeam vers le TrueNAS (2e copie, règle 3-2-1)
$dst = '\\truenas.redone.local\copie-veeam'
$log = 'C:\Scripts\copie-truenas.log'
robocopy S:\Sauvegardes $dst /MIR /Z /R:2 /W:30 /NP /NDL /LOG:$log /TEE | Out-Null
$rc = $LASTEXITCODE
$etat = if ($rc -lt 8) { 'OK' } else { 'ECHEC' }
"$(Get-Date -f 'yyyy-MM-dd HH:mm:ss') copie $etat (robocopy $rc)" | Out-File C:\Scripts\copie-truenas-historique.log -Append -Encoding utf8
if ($rc -ge 8) { Write-EventLog -LogName Application -Source 'RedOne-Sauvegarde' -EventId 1001 -EntryType Error -Message "Copie vers le TrueNAS en échec (robocopy $rc)" }
else { Write-EventLog -LogName Application -Source 'RedOne-Sauvegarde' -EventId 1000 -EntryType Information -Message "Copie vers le TrueNAS réussie (robocopy $rc)" }
exit $rc
'@
[IO.File]::WriteAllText('C:\Scripts\copie-truenas.ps1', $script, (New-Object Text.UTF8Encoding $true))
if (-not [Diagnostics.EventLog]::SourceExists('RedOne-Sauvegarde')) { New-EventLog -LogName Application -Source 'RedOne-Sauvegarde' }
$a = New-ScheduledTaskAction -Execute powershell.exe -Argument '-NoProfile -ExecutionPolicy Bypass -File C:\Scripts\copie-truenas.ps1'
$t = New-ScheduledTaskTrigger -Daily -At 04:00
$s = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 4) -StartWhenAvailable
Register-ScheduledTask -TaskName 'RedOne - Copie sauvegardes vers TrueNAS' -Action $a -Trigger $t -Settings $s -User SYSTEM -RunLevel Highest -Description 'Copie miroir de S:\Sauvegardes vers \\truenas\copie-veeam chaque nuit a 4h' -Force | Out-Null
# Test immédiat
Set-Content S:\Sauvegardes\LISEZMOI.txt "Depot Veeam RedOne - SRV-VEEAM (10.2.1.53). Copie chaque nuit vers \\truenas.redone.local\copie-veeam." -Encoding UTF8
Start-ScheduledTask 'RedOne - Copie sauvegardes vers TrueNAS'; Start-Sleep 15
Get-Content C:\Scripts\copie-truenas-historique.log -Tail 1
(Get-ScheduledTask 'RedOne - Copie sauvegardes vers TrueNAS' | Get-ScheduledTaskInfo) | % { "dernier résultat $($_.LastTaskResult), prochaine exécution $($_.NextRunTime)" }

1..8 | ForEach-Object { cmd /c "net use \\REDONE\IPC$ /user:REDONE\attaquant Faux-Mdp-$_ >nul 2>&1" }
cmd /c "net use \\REDONE\IPC$ /delete /y >nul 2>&1"
Start-Sleep 3
"Evenements 4625 recents : " + (Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4625; StartTime=(Get-Date).AddMinutes(-2)} -ErrorAction SilentlyContinue).Count
"Evenements 4776 recents : " + (Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4776; StartTime=(Get-Date).AddMinutes(-2)} -ErrorAction SilentlyContinue).Count

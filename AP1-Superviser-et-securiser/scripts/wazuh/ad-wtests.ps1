Import-Module ActiveDirectory
# Audit (GUID = indépendant de la langue) : Ouverture de session, Validation des informations d'identification, Gestion des comptes
foreach ($g in '{0CCE9215-69AE-11D9-BED3-505054503030}','{0CCE923F-69AE-11D9-BED3-505054503030}','{0CCE9235-69AE-11D9-BED3-505054503030}') {
  auditpol /set /subcategory:$g /success:enable /failure:enable | Out-Null }
"Audit active"
Start-Sleep 5
# Test 1 : 8 tentatives d'authentification avec un compte inexistant (mot de passe factice)
1..8 | ForEach-Object {
  $de = New-Object DirectoryServices.DirectoryEntry('LDAP://RedOne.local', 'REDONE\attaquant', ('Faux-' + $_))
  try { $null = $de.NativeObject } catch {} }
"8 echecs d'authentification generes"
Start-Sleep 3
# Test 2 : création puis suppression d'un compte de test
$pw = ConvertTo-SecureString ([guid]::NewGuid().ToString() + 'Aa1!') -AsPlainText -Force
New-ADUser -Name 'intrus.test' -SamAccountName 'intrus.test' -AccountPassword $pw -Enabled $true -Path 'CN=Users,DC=RedOne,DC=local'
Start-Sleep 5
Remove-ADUser -Identity 'intrus.test' -Confirm:$false
"Compte intrus.test cree puis supprime"
"Evenements 4625 recents : " + (Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4625; StartTime=(Get-Date).AddMinutes(-3)} -ErrorAction SilentlyContinue).Count
"Evenements 4771/4776 recents : " + (Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4771,4776; StartTime=(Get-Date).AddMinutes(-3)} -ErrorAction SilentlyContinue).Count
"Evenement 4720 recent : " + (Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4720; StartTime=(Get-Date).AddMinutes(-3)} -ErrorAction SilentlyContinue).Count

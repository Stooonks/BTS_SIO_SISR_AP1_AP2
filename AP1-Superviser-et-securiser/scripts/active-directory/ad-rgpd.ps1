$ErrorActionPreference = 'Stop'
Import-Module GroupPolicy, ActiveDirectory
function SetGP { for ($i = 1; $i -le 8; $i++) { try { Set-GPRegistryValue @args -ErrorAction Stop | Out-Null; return } catch { if ($i -eq 8) { throw }; Start-Sleep -Milliseconds (400 * $i) } } }
$d = Get-ADDomain

# 1. Politique de mots de passe du domaine (recommandation CNIL 2022 : 12 caractères et 4 types, ou blocage du compte)
$avant = Get-ADDefaultDomainPasswordPolicy
"avant : longueur $($avant.MinPasswordLength), complexité $($avant.ComplexityEnabled), verrouillage $($avant.LockoutThreshold), historique $($avant.PasswordHistoryCount)"
Set-ADDefaultDomainPasswordPolicy -Identity $d.DNSRoot -MinPasswordLength 12 -ComplexityEnabled $true -PasswordHistoryCount 24 `
  -LockoutThreshold 10 -LockoutDuration '00:15:00' -LockoutObservationWindow '00:15:00' -MinPasswordAge '1.00:00:00' -ReversibleEncryptionEnabled $false
$p = Get-ADDefaultDomainPasswordPolicy
"après : longueur $($p.MinPasswordLength), complexité $($p.ComplexityEnabled), verrouillage $($p.LockoutThreshold) essais / $($p.LockoutDuration), historique $($p.PasswordHistoryCount), chiffrement réversible $($p.ReversibleEncryptionEnabled)"

# 2. Information des utilisateurs à l'ouverture de session (RGPD art. 13, Code du travail L1222-4)
$name = 'RedOne - Information des utilisateurs (RGPD)'
$g = Get-GPO -Name $name -EA SilentlyContinue
if (-not $g) { $g = New-GPO -Name $name -Comment 'Message affiché avant chaque ouverture de session : journalisation et supervision du SI' }
if (-not ((Get-GPInheritance $d.DistinguishedName).GpoLinks.DisplayName -contains $name)) { New-GPLink -Guid $g.Id -Target $d.DistinguishedName | Out-Null }
$k = 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
$titre = 'RedOne - Système d''information à usage professionnel'
$texte = 'L''accès est réservé aux personnes autorisées. Pour la sécurité du système d''information, les connexions et les actions sont journalisées et supervisées (Wazuh, Zabbix), puis conservées de 90 jours à 1 an selon la charte informatique. Les données personnelles sont traitées par la DSI de RedOne conformément au RGPD. Droits d''accès, de rectification et d''opposition : dpo@redone.com.'
SetGP -Guid $g.Id -Key $k -ValueName legalnoticecaption -Type String -Value $titre
SetGP -Guid $g.Id -Key $k -ValueName legalnoticetext -Type String -Value $texte
# Ne pas afficher le nom du dernier utilisateur connecté (minimisation)
SetGP -Guid $g.Id -Key $k -ValueName dontdisplaylastusername -Type DWord -Value 1
# Verrouillage automatique de la session après 15 min d'inactivité
SetGP -Guid $g.Id -Key $k -ValueName InactivityTimeoutSecs -Type DWord -Value 900
"GPO '$name' liée au domaine"
repadmin /syncall /AdeP | Out-Null

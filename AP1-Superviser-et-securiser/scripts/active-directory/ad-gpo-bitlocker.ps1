$ErrorActionPreference = 'Stop'
Import-Module GroupPolicy, ActiveDirectory
function SetGP { for ($i = 1; $i -le 8; $i++) { try { Set-GPRegistryValue @args -ErrorAction Stop | Out-Null; return } catch { if ($i -eq 8) { throw }; Start-Sleep -Milliseconds (400 * $i) } } }
$d = Get-ADDomain; $ou = "OU=Serveurs,$($d.DistinguishedName)"
$name = 'RedOne - BitLocker (cles de recuperation dans l AD)'
$g = Get-GPO -Name $name -EA SilentlyContinue
if (-not $g) { $g = New-GPO -Name $name -Comment 'Chiffrement XTS-AES 256 et sauvegarde obligatoire des cles de recuperation BitLocker dans l Active Directory' }
if (-not ((Get-GPInheritance $ou).GpoLinks.DisplayName -contains $name)) { New-GPLink -Guid $g.Id -Target $ou | Out-Null }
$k = 'HKLM\SOFTWARE\Policies\Microsoft\FVE'
$v = @{ EncryptionMethodWithXtsOs = 7; EncryptionMethodWithXtsFdv = 7; EncryptionMethodWithXtsRdv = 4
        OSRecovery = 1; OSManageDRA = 1; OSRecoveryPassword = 2; OSRecoveryKey = 2; OSHideRecoveryPage = 0
        OSActiveDirectoryBackup = 1; OSActiveDirectoryInfoToStore = 1; OSRequireActiveDirectoryBackup = 1
        FDVRecovery = 1; FDVManageDRA = 1; FDVRecoveryPassword = 2; FDVRecoveryKey = 2; FDVHideRecoveryPage = 0
        FDVActiveDirectoryBackup = 1; FDVActiveDirectoryInfoToStore = 1; FDVRequireActiveDirectoryBackup = 1 }
foreach ($n in $v.Keys) { SetGP -Guid $g.Id -Key $k -ValueName $n -Type DWord -Value $v[$n] }
"GPO '$name' liée à OU=Serveurs ($($v.Count) paramètres)"
repadmin /syncall /AdeP | Out-Null

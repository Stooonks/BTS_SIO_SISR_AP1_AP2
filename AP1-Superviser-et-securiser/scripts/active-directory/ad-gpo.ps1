$ErrorActionPreference = 'Stop'
Import-Module GroupPolicy, ActiveDirectory
$dom   = Get-ADDomain
$fqdn  = $dom.DNSRoot
$name  = 'RedOne - Lecteur Z Partages'
$gpo = Get-GPO -Name $name -ErrorAction SilentlyContinue
if (-not $gpo) { $gpo = New-GPO -Name $name -Comment 'Connecte \\REDONE\Partages en Z: pour tous les employés (GPP Lecteurs)' }
$guid = "{$($gpo.Id.ToString().ToUpper())}"
$gpoPath = "\\$fqdn\SYSVOL\$fqdn\Policies\$guid"

# Préférence « Lecteurs mappés » (configuration utilisateur)
$dir = "$gpoPath\User\Preferences\Drives"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$uid = "{$([guid]::NewGuid().ToString().ToUpper())}"
$now = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
$xml = @"
<?xml version="1.0" encoding="utf-8"?>
<Drives clsid="{8FDDCC1A-0C3C-43cd-A6B4-71A6DF20DA8C}"><Drive clsid="{935D1B74-9CB8-4e3c-9914-7DD559B7A417}" name="Z:" status="Z:" image="2" changed="$now" uid="$uid" bypassErrors="1"><Properties action="U" thisDrive="SHOW" allDrives="NOCHANGE" userName="" path="\\REDONE\Partages" label="Partages RedOne" persistent="1" useLetter="1" letter="Z"/></Drive></Drives>
"@
[IO.File]::WriteAllText("$dir\Drives.xml", $xml, (New-Object Text.UTF8Encoding $true))

# Déclaration de l'extension GPP + incrément de version (côté utilisateur)
$ext = '[{00000000-0000-0000-0000-000000000000}{2EA1A81B-48E5-45E9-8BB7-A6E3AC170006}][{5794DAFD-BE60-433F-88A2-1A31939AC01F}{2EA1A81B-48E5-45E9-8BB7-A6E3AC170006}]'
$gpoDN = "CN=$guid,CN=Policies,CN=System,$($dom.DistinguishedName)"
$cur = (Get-ADObject $gpoDN -Properties versionNumber).versionNumber
$userVer = [int]([math]::Floor($cur / 65536)) + 1
$newVer = [int](($userVer * 65536) + ($cur % 65536))
Set-ADObject $gpoDN -Replace @{ gPCUserExtensionNames = $ext; versionNumber = $newVer }
$ini = "$gpoPath\GPT.INI"
"[General]`r`nVersion=$newVer`r`ndisplayName=$name" | Set-Content -Path $ini -Encoding ASCII

# Liaison à la racine du domaine (tous les utilisateurs)
if (-not ((Get-GPInheritance -Target $dom.DistinguishedName).GpoLinks | Where-Object DisplayName -eq $name)) {
  New-GPLink -Name $name -Target $dom.DistinguishedName -LinkEnabled Yes | Out-Null }
$g = Get-GPO -Name $name
"GPO_OK : $name | version utilisateur AD=$($g.User.DSVersion) SYSVOL=$($g.User.SysvolVersion) | liée à $($dom.DistinguishedName)"

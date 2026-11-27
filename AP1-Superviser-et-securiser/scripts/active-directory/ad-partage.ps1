$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory
$nb   = (Get-ADDomain).NetBIOSName
$root = 'C:\Partages'
$folders = 'Commun','Accueil','Commercial','Communication-Redaction','Demonstration','Developpement','Direction-DSI','DSI-Technique','Labo-Recherche','RH-Compta-Juridique','Visiteurs-Medicaux'

New-Item -ItemType Directory -Force -Path $root | Out-Null
foreach ($f in $folders) { New-Item -ItemType Directory -Force -Path (Join-Path $root $f) | Out-Null }
New-Item -ItemType Directory -Force -Path "$root\Visiteurs-Medicaux\Notes-de-frais","$root\Visiteurs-Medicaux\Remontees-terrain" | Out-Null

$FC  = [Security.AccessControl.FileSystemRights]::FullControl
$MOD = [Security.AccessControl.FileSystemRights]::Modify
$RX  = [Security.AccessControl.FileSystemRights]::ReadAndExecute
$LST = [Security.AccessControl.FileSystemRights]'ReadAndExecute, Synchronize'
$CIOI = [Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'
$NONE = [Security.AccessControl.InheritanceFlags]::None
$NP   = [Security.AccessControl.PropagationFlags]::None

function Rule($id, $rights, $inh) { New-Object Security.AccessControl.FileSystemAccessRule($id, $rights, $inh, $NP, 'Allow') }

function Set-Acl-Clean($path, [object[]]$rules) {
  $acl = New-Object Security.AccessControl.DirectorySecurity
  $acl.SetAccessRuleProtection($true, $false)              # héritage coupé, ACL maîtrisée
  $acl.AddAccessRule((Rule 'BUILTIN\Administrateurs' $FC $CIOI))
  $acl.AddAccessRule((Rule 'NT AUTHORITY\SYSTEM' $FC $CIOI))
  $acl.AddAccessRule((Rule "$nb\DL_Partages_FC" $FC $CIOI))
  foreach ($r in $rules) { $acl.AddAccessRule($r) }
  Set-Acl -Path $path -AclObject $acl }

# Racine : chacun peut l'ouvrir (ce dossier seulement) ; ABE masque ce qu'il ne peut pas lire
Set-Acl-Clean $root @( (Rule "$nb\DL_Partages_List" $LST $NONE) )

foreach ($f in $folders) {
  $p = Join-Path $root $f
  $rules = @( (Rule "$nb\DL_$f`_RW" $MOD $CIOI), (Rule "$nb\DL_$f`_R" $RX $CIOI) )
  if ($f -eq 'Visiteurs-Medicaux') {
    # Compta, Rédaction et Labo peuvent traverser ce dossier pour atteindre leur sous-dossier
    $rules += (Rule "$nb\DL_Visiteurs-Frais_R" $LST $NONE)
    $rules += (Rule "$nb\DL_Visiteurs-Remontees_R" $LST $NONE) }
  Set-Acl-Clean $p $rules }

# Sous-dossiers des visiteurs : héritage conservé + lecture ciblée
foreach ($pair in @(@('Notes-de-frais','DL_Visiteurs-Frais_R'), @('Remontees-terrain','DL_Visiteurs-Remontees_R'))) {
  $p = "$root\Visiteurs-Medicaux\$($pair[0])"
  $acl = Get-Acl $p
  $acl.AddAccessRule((Rule "$nb\$($pair[1])" $RX $CIOI))
  Set-Acl -Path $p -AclObject $acl }

# Partage SMB : droits de partage larges, la sécurité est portée par NTFS ; énumération basée sur l'accès
if (-not (Get-SmbShare -Name 'Partages' -ErrorAction SilentlyContinue)) {
  New-SmbShare -Name 'Partages' -Path $root -FullAccess 'BUILTIN\Administrateurs' -ChangeAccess 'NT AUTHORITY\Utilisateurs authentifiés' `
    -FolderEnumerationMode AccessBased -CachingMode None -Description 'Dossiers partagés RedOne (lecteur Z:)' | Out-Null }
Set-SmbShare -Name 'Partages' -FolderEnumerationMode AccessBased -EncryptData $true -Force
"PARTAGE_OK : \\$env:COMPUTERNAME\Partages -> $root"

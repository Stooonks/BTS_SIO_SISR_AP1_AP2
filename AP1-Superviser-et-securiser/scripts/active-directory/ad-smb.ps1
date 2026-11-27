$ErrorActionPreference = 'Stop'
function SidName($sid) { (New-Object Security.Principal.SecurityIdentifier($sid)).Translate([Security.Principal.NTAccount]).Value }
$admins = SidName 'S-1-5-32-544'
$auth   = SidName 'S-1-5-11'
if (-not (Get-SmbShare -Name 'Partages' -ErrorAction SilentlyContinue)) {
  New-SmbShare -Name 'Partages' -Path 'C:\Partages' -FullAccess $admins -ChangeAccess $auth `
    -FolderEnumerationMode AccessBased -CachingMode None -Description 'Dossiers partagés RedOne (lecteur Z:)' | Out-Null }
Set-SmbShare -Name 'Partages' -FolderEnumerationMode AccessBased -EncryptData $true -Force
$s = Get-SmbShare -Name 'Partages'
"PARTAGE_OK : \\$env:COMPUTERNAME\$($s.Name) -> $($s.Path) | ABE=$($s.FolderEnumerationMode) | Chiffrement=$($s.EncryptData)"
Get-SmbShareAccess -Name 'Partages' | ForEach-Object { "  {0} : {1}" -f $_.AccountName, $_.AccessRight }
"== ACL NTFS"
foreach ($p in Get-ChildItem C:\Partages -Directory) {
  $ids = (Get-Acl $p.FullName).Access | Where-Object { $_.IdentityReference -like '*\DL_*' } |
    ForEach-Object { "{0}({1})" -f ($_.IdentityReference -replace '.*\\DL_',''), ($(if ($_.FileSystemRights -match 'Modify') {'RW'} elseif ($_.FileSystemRights -match 'FullControl') {'FC'} else {'R'})) }
  "{0,-24} {1}" -f $p.Name, ($ids -join '  ') }

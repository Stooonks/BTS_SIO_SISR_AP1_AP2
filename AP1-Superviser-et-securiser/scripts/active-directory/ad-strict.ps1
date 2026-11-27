$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory
# Accès strict : la Direction ne lit plus les dossiers des autres services
$dir = Get-ADGroup 'GG_Direction-DSI'
foreach ($g in Get-ADGroup -Filter "Name -like 'DL_*_R'" ) {
  if ($g.Name -in 'DL_Visiteurs-Frais_R','DL_Visiteurs-Remontees_R','DL_Visiteurs-Medicaux_R') {
    # le partage métier des visiteurs reste prévu par le contexte (Compta, Rédaction, Labo, Commercial)
    if ($g.Name -eq 'DL_Visiteurs-Medicaux_R') { Remove-ADGroupMember $g -Members $dir -Confirm:$false -ErrorAction SilentlyContinue }
    continue }
  Remove-ADGroupMember $g -Members $dir -Confirm:$false -ErrorAction SilentlyContinue }
"Direction retirée des groupes de lecture des autres services"

"== Accès effectif par utilisateur"
foreach ($u0 in Get-ADUser -Filter * -SearchBase (Get-ADDomain).DistinguishedName | Where-Object { $_.DistinguishedName -notmatch 'CN=Users|CN=Builtin' } | Sort-Object SamAccountName) {
  $u = Get-ADUser -Identity $u0.DistinguishedName -Properties tokenGroups
  $acc = foreach ($sid in $u.tokenGroups) {
    $n = try { (New-Object Security.Principal.SecurityIdentifier($sid)).Translate([Security.Principal.NTAccount]).Value } catch { '' }
    if ($n -match '\\DL_(.+)$' -and $Matches[1] -ne 'Partages_List') { $Matches[1] } }
  $txt = ($acc | Sort-Object | ForEach-Object {
      if ($_ -eq 'Partages_FC') { 'TOUT (contrôle total, admin IT)' }
      elseif ($_ -like '*_RW') { ($_ -replace '_RW$','') + ' [RW]' }
      else { ($_ -replace '_R$','') + ' [R]' } }) -join ', '
  "{0,-10} {1,-17} {2}" -f $u.SamAccountName, $u.Name, $txt }

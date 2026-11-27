$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory
$domDN = (Get-ADDomain).DistinguishedName
$nb    = (Get-ADDomain).NetBIOSName

function Normalize([string]$s) {
  $d = $s.Normalize([Text.NormalizationForm]::FormD)
  -join ($d.ToCharArray() | Where-Object { [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark' })
}

# --- OU des groupes
if (-not (Get-ADOrganizationalUnit -LDAPFilter '(ou=Groupes)' -SearchBase $domDN -SearchScope OneLevel)) {
  New-ADOrganizationalUnit -Name 'Groupes' -Path $domDN -ProtectedFromAccidentalDeletion $true }
$gOU = "OU=Groupes,$domDN"
foreach ($sub in 'Globaux','Domaine-Local') {
  if (-not (Get-ADOrganizationalUnit -LDAPFilter "(ou=$sub)" -SearchBase $gOU -SearchScope OneLevel)) {
    New-ADOrganizationalUnit -Name $sub -Path $gOU -ProtectedFromAccidentalDeletion $true } }
$ggOU = "OU=Globaux,$gOU"; $dlOU = "OU=Domaine-Local,$gOU"

function Ensure-Group($name, $scope, $path, $desc) {
  $g = Get-ADGroup -LDAPFilter "(sAMAccountName=$name)"
  if (-not $g) { $g = New-ADGroup -Name $name -SamAccountName $name -GroupScope $scope -GroupCategory Security -Path $path -Description $desc -PassThru }
  return $g }

# --- Correspondance OU -> service
$map = @{
  'Accueil'='Accueil'; 'Commercial'='Commercial'; 'Communication-Redaction'='Communication-Redaction';
  'Demonstration'='Demonstration'; 'Developpement'='Developpement'; 'Direction-DSI'='Direction-DSI';
  'Labo-Recherche'='Labo-Recherche'; 'Reseau-Systeme'='Reseau-Systeme';
  'RH-Compta-Juridique-Secretariat'='RH-Compta-Juridique'; 'Serveurs'='Exploitation-Serveurs';
  'Sortie'='Sortie'; 'Visiteurs'='Visiteurs-Medicaux' }
$desc = @{
  'Accueil'='Accueil du siège (VLAN 100)'; 'Commercial'='Service commercial (VLAN 60)';
  'Communication-Redaction'='Communication / Rédaction des notices (VLAN 40)'; 'Demonstration'='Salle Démonstration (VLAN 200)';
  'Developpement'='Développement - applications flotte visite (VLAN 50)'; 'Direction-DSI'='Direction / DSI (VLAN 20)';
  'Labo-Recherche'='Labo-Recherche (VLAN 70)'; 'Reseau-Systeme'='Réseau & Système - administration IT (VLAN 10)';
  'RH-Compta-Juridique'='RH / Compta / Juridique / Secrétariat (VLAN 30)'; 'Exploitation-Serveurs'='Exploitation des serveurs (VLAN 300)';
  'Sortie'='Comptes de l OU Sortie - accès commun uniquement'; 'Visiteurs-Medicaux'='Visiteurs médicaux terrain (VLAN 150)' }

# --- Groupes globaux par service + tous les employés
$GG = @{}
foreach ($svc in ($map.Values | Sort-Object -Unique)) { $GG[$svc] = Ensure-Group "GG_$svc" Global $ggOU $desc[$svc] }
$GGall = Ensure-Group 'GG_Tous-Employes' Global $ggOU 'Tous les employés RedOne'

# --- Rattachement des utilisateurs selon leur OU
$report = @()
foreach ($ou in Get-ADOrganizationalUnit -Filter * -SearchBase $domDN -SearchScope OneLevel) {
  $key = Normalize $ou.Name
  if (-not $map.ContainsKey($key)) { continue }
  $svc = $map[$key]
  foreach ($u in Get-ADUser -SearchBase $ou.DistinguishedName -SearchScope OneLevel -Filter *) {
    Add-ADGroupMember -Identity $GG[$svc] -Members $u
    Add-ADGroupMember -Identity $GGall -Members $u
    if ($svc -eq 'Visiteurs-Medicaux') { Set-ADUser $u -Department 'Visiteurs médicaux' -Title 'Visiteur médical' }
    $report += "{0,-12} -> GG_{1}" -f $u.SamAccountName, $svc } }
$report

# --- Groupes domaine local (droits sur les dossiers)
$folders = 'Commun','Accueil','Commercial','Communication-Redaction','Demonstration','Developpement','Direction-DSI','DSI-Technique','Labo-Recherche','RH-Compta-Juridique','Visiteurs-Medicaux'
$DL = @{}
foreach ($f in $folders) {
  $DL["$f`_RW"] = Ensure-Group "DL_$f`_RW" DomainLocal $dlOU "Modification sur \\Partages\$f"
  $DL["$f`_R"]  = Ensure-Group "DL_$f`_R"  DomainLocal $dlOU "Lecture sur \\Partages\$f" }
$DL['Partages_FC']   = Ensure-Group 'DL_Partages_FC'   DomainLocal $dlOU 'Contrôle total sur tout le partage (administrateurs IT)'
$DL['Partages_List'] = Ensure-Group 'DL_Partages_List' DomainLocal $dlOU 'Ouverture de la racine du partage'
$DL['Frais_R']       = Ensure-Group 'DL_Visiteurs-Frais_R'      DomainLocal $dlOU 'Lecture des notes de frais des visiteurs'
$DL['Remontees_R']   = Ensure-Group 'DL_Visiteurs-Remontees_R'  DomainLocal $dlOU 'Lecture des remontées terrain des visiteurs'

# --- AGDLP : GG dans DL
function Nest($dlKey, [string[]]$svcs) { foreach ($s in $svcs) { Add-ADGroupMember -Identity $DL[$dlKey] -Members $(if ($s -eq 'ALL') { $GGall } else { $GG[$s] }) } }
Nest 'Commun_RW' 'ALL'
Nest 'Partages_List' 'ALL'
Nest 'Partages_FC' 'Reseau-Systeme'
foreach ($f in 'Accueil','Commercial','Communication-Redaction','Demonstration','Developpement','Direction-DSI','Labo-Recherche','RH-Compta-Juridique','Visiteurs-Medicaux') {
  Nest "$f`_RW" $f
  if ($f -ne 'Direction-DSI') { Nest "$f`_R" 'Direction-DSI' } }
Nest 'DSI-Technique_RW' 'Reseau-Systeme','Exploitation-Serveurs'
Nest 'DSI-Technique_R' 'Direction-DSI'
Nest 'Visiteurs-Medicaux_R' 'Commercial'
Nest 'Frais_R' 'RH-Compta-Juridique'
Nest 'Remontees_R' 'Communication-Redaction','Labo-Recherche'

# --- Délégation : Réseau-Système réinitialise les mots de passe et déverrouille les comptes
$tech = "$nb\GG_Reseau-Systeme"
foreach ($ou in Get-ADOrganizationalUnit -Filter * -SearchBase $domDN -SearchScope OneLevel) {
  $key = Normalize $ou.Name
  if (-not $map.ContainsKey($key)) { continue }
  dsacls $ou.DistinguishedName /I:S /G "${tech}:CA;Reset Password;user" | Out-Null
  dsacls $ou.DistinguishedName /I:S /G "${tech}:RPWP;pwdLastSet;user" | Out-Null
  dsacls $ou.DistinguishedName /I:S /G "${tech}:RPWP;lockoutTime;user" | Out-Null }
"DELEGATION_OK"
"GROUPES_OK"

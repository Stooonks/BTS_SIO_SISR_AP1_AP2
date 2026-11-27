$ErrorActionPreference = 'Stop'
Import-Module GroupPolicy, ActiveDirectory
$dom  = Get-ADDomain
$nb   = $dom.NetBIOSName
$fqdn = $dom.DNSRoot
$authUsers = (New-Object Security.Principal.SecurityIdentifier('S-1-5-11')).Translate([Security.Principal.NTAccount]).Value

$roles = @(
  @{ Key='tech';       Nom='Tech';       Groupes=@('GG_Reseau-Systeme','GG_Exploitation-Serveurs') },
  @{ Key='rh';         Nom='RH';         Groupes=@('GG_RH-Compta-Juridique') },
  @{ Key='commercial'; Nom='Commercial'; Groupes=@('GG_Commercial') },
  @{ Key='admin';      Nom='Admin';      Groupes=@('GG_Direction-DSI') }
)
$sys = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System'
$act = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop'

foreach ($r in $roles) {
  $name = "RedOne - Fond d'ecran $($r.Nom)"
  $gpo = Get-GPO -Name $name -ErrorAction SilentlyContinue
  if (-not $gpo) { $gpo = New-GPO -Name $name -Comment "Fond d'écran du rôle $($r.Nom) - filtré sur $($r.Groupes -join ', ')" }
  $img = "\\$fqdn\NETLOGON\FondsEcran\fond-$($r.Key).jpg"
  # Configuration utilisateur > Modèles d'administration > Bureau > Bureau > Papier peint du Bureau
  Set-GPRegistryValue -Name $name -Key $sys -ValueName 'Wallpaper'      -Type String -Value $img | Out-Null
  Set-GPRegistryValue -Name $name -Key $sys -ValueName 'WallpaperStyle' -Type String -Value '4' | Out-Null   # 4 = Remplir
  # Empêche l'utilisateur de changer le fond d'écran
  Set-GPRegistryValue -Name $name -Key $act -ValueName 'NoChangingWallPaper' -Type DWord -Value 1 | Out-Null
  # La configuration ordinateur n'est pas utilisée
  $gpo.GpoStatus = 'ComputerSettingsDisabled'

  # Filtrage de sécurité : lecture pour tous (MS16-072), application uniquement pour le rôle
  Set-GPPermission -Name $name -TargetName $authUsers -TargetType Group -PermissionLevel GpoRead -Replace | Out-Null
  foreach ($grp in $r.Groupes) { Set-GPPermission -Name $name -TargetName $grp -TargetType Group -PermissionLevel GpoApply | Out-Null }

  if (-not ((Get-GPInheritance -Target $dom.DistinguishedName).GpoLinks | Where-Object DisplayName -eq $name)) {
    New-GPLink -Name $name -Target $dom.DistinguishedName -LinkEnabled Yes | Out-Null }

  $apply = (Get-GPPermission -Name $name -All | Where-Object Permission -eq 'GpoApply' | ForEach-Object { $_.Trustee.Name }) -join ', '
  $g = Get-GPO -Name $name
  "{0,-30} statut={1,-24} s'applique a : {2}" -f $name, $g.GpoStatus, $apply
  "    papier peint = {0}  (fichier present : {1})" -f $img, (Test-Path "C:\Windows\SYSVOL\sysvol\$fqdn\scripts\FondsEcran\fond-$($r.Key).jpg")
}
"== Liens a la racine du domaine"
(Get-GPInheritance -Target $dom.DistinguishedName).GpoLinks | ForEach-Object { "  {0}. {1}" -f $_.Order, $_.DisplayName }

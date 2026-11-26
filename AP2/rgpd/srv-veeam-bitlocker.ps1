# RGPD art. 32 : chiffrement au repos du serveur de sauvegarde (BitLocker XTS-AES 256, TPM)
# Clés de récupération sauvegardées dans l'Active Directory (objet ordinateur SRV-VEEAM)
$ErrorActionPreference = 'Stop'
Start-Sleep 20
# Volume système : protecteur TPM + mot de passe de récupération
$c = Get-BitLockerVolume C:
if ($c.VolumeStatus -eq 'FullyDecrypted') {
  Add-BitLockerKeyProtector C: -RecoveryPasswordProtector -WarningAction SilentlyContinue | Out-Null
  Enable-BitLocker C: -EncryptionMethod XtsAes256 -TpmProtector -UsedSpaceOnly -SkipHardwareTest -WarningAction SilentlyContinue | Out-Null
}
# Dépôt de sauvegarde S: : mot de passe de récupération + déverrouillage automatique
$s = Get-BitLockerVolume S:
if ($s.VolumeStatus -eq 'FullyDecrypted') {
  Enable-BitLocker S: -EncryptionMethod XtsAes256 -RecoveryPasswordProtector -UsedSpaceOnly -WarningAction SilentlyContinue | Out-Null
}
Start-Sleep 5
try { Enable-BitLockerAutoUnlock S: | Out-Null } catch { "déverrouillage auto S: : $($_.Exception.Message)" }
foreach ($v in 'C:', 'S:') {
  $b = Get-BitLockerVolume $v
  foreach ($kp in $b.KeyProtector | ? KeyProtectorType -eq 'RecoveryPassword') {
    Backup-BitLockerKeyProtector -MountPoint $v -KeyProtectorId $kp.KeyProtectorId | Out-Null
  }
  '{0} {1} {2} {3}% protecteurs={4}' -f $v, $b.VolumeStatus, $b.EncryptionMethod, $b.EncryptionPercentage, (($b.KeyProtector.KeyProtectorType) -join ',')
}

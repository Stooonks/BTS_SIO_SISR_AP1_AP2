# Installation automatique sur les serveurs RedOne (déployée par GPO, exécutée en SYSTEM)
# - agent invité QEMU (depuis le CD virtio) et Veeam Agent (depuis \\SRV-VEEAM\Logiciels$)
$log = 'C:\Windows\Temp\redone-setup.log'
function L($m){ "$(Get-Date -f 'yyyy-MM-dd HH:mm:ss') $m" | Out-File $log -Append -Encoding utf8 }
L "=== démarrage sur $env:COMPUTERNAME"
if (-not (Get-Service QEMU-GA -EA SilentlyContinue)) {
  $cd = Get-PSDrive -PSProvider FileSystem | ? { Test-Path "$($_.Root)guest-agent\qemu-ga-x86_64.msi" } | select -First 1
  if ($cd) {
    $drv = Get-ChildItem "$($cd.Root)vioserial" -Recurse -Filter vioser.inf | ? FullName -match '2k22\\amd64' | select -First 1
    if ($drv) { pnputil /add-driver $drv.FullName /install | Out-Null; L "pilote vioserial : $($drv.FullName)" }
    $p = Start-Process msiexec -Wait -PassThru -ArgumentList "/i `"$($cd.Root)guest-agent\qemu-ga-x86_64.msi`" /qn"
    L "agent QEMU : code $($p.ExitCode)"
  } else { L 'CD virtio introuvable' }
}
if (-not (Get-Service VeeamEndpointBackupSvc -EA SilentlyContinue)) {
  $src = '\\SRV-VEEAM\Logiciels$\VeeamAgentWindows_6.0.0.960.exe'; $exe = 'C:\Windows\Temp\VeeamAgentWindows_6.0.0.960.exe'
  try {
    Copy-Item $src $exe -Force -ErrorAction Stop
    if ((Get-FileHash $exe).Hash -eq 'DA34949F6FDCF578D6C63655AFF797C02CA6B7C19D16A42063E5448648D6F050' -and (Get-AuthenticodeSignature $exe).Status -eq 'Valid') {
      $p = Start-Process $exe -Wait -PassThru -ArgumentList '/silent /accepteula /acceptthirdpartylicenses'; L "Veeam : code $($p.ExitCode)"
    } else { L 'installeur Veeam non conforme' }
  } catch { L "Veeam : $($_.Exception.Message)" }
}
L ('services : ' + ((Get-Service QEMU-GA,VeeamEndpointBackupSvc -EA SilentlyContinue | % { "$($_.Name)=$($_.Status)" }) -join ' '))

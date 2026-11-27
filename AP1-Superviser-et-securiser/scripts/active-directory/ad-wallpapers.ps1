$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$fqdn = (Get-ADDomain).DNSRoot
$dir  = "C:\Windows\SYSVOL\sysvol\$fqdn\scripts\FondsEcran"
New-Item -ItemType Directory -Force -Path $dir | Out-Null

$roles = @(
  @{ Key='Tech';       Titre='Service Technique';  Sous='Réseau & Système  ·  Exploitation des serveurs'; C1='#0B1F3A'; C2='#1F6FB2' },
  @{ Key='RH';         Titre='Ressources Humaines'; Sous='RH  ·  Comptabilité  ·  Juridique  ·  Secrétariat'; C1='#0F3D2E'; C2='#2E9E6B' },
  @{ Key='Commercial'; Titre='Service Commercial';  Sous='Suivi des secteurs  ·  Visiteurs médicaux'; C1='#5A2A00'; C2='#E07B1A' },
  @{ Key='Admin';      Titre='Direction / DSI';     Sous='Direction générale  ·  Direction des Services Informatiques'; C1='#3B0A14'; C2='#9E1F3A' }
)

function Col($hex) { [Drawing.ColorTranslator]::FromHtml($hex) }
$W = 1920; $H = 1080
foreach ($r in $roles) {
  $bmp = New-Object Drawing.Bitmap $W, $H
  $g = [Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'
  $rect = New-Object Drawing.Rectangle 0, 0, $W, $H
  $br = New-Object Drawing.Drawing2D.LinearGradientBrush $rect, (Col $r.C1), (Col $r.C2), 35
  $g.FillRectangle($br, $rect)
  # motif discret
  $pen = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(18, 255, 255, 255)), 2
  for ($x = -$H; $x -lt $W; $x += 60) { $g.DrawLine($pen, $x, $H, $x + $H, 0) }
  $white = [Drawing.Brushes]::White
  $soft  = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(200, 255, 255, 255))
  $fLogo = New-Object Drawing.Font 'Segoe UI', 54, ([Drawing.FontStyle]::Bold)
  $fTit  = New-Object Drawing.Font 'Segoe UI Light', 72
  $fSous = New-Object Drawing.Font 'Segoe UI', 26
  $fBas  = New-Object Drawing.Font 'Segoe UI', 16
  $g.DrawString('RedOne', $fLogo, $white, 120, 120)
  $g.FillRectangle($soft, 124, 215, 260, 5)
  $g.DrawString($r.Titre, $fTit, $white, 115, 420)
  $g.DrawString($r.Sous, $fSous, $soft, 125, 545)
  $g.DrawString('Laboratoire RedOne  -  Siège Europe, Paris          Support : http://192.168.100.208 (GLPI)          Données : lecteur Z:', $fBas, $soft, 125, $H - 90)
  $path = Join-Path $dir ("fond-{0}.jpg" -f $r.Key.ToLower())
  $enc = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object MimeType -eq 'image/jpeg'
  $ep = New-Object Drawing.Imaging.EncoderParameters 1
  $ep.Param[0] = New-Object Drawing.Imaging.EncoderParameter ([Drawing.Imaging.Encoder]::Quality), 90L
  $bmp.Save($path, $enc, $ep)
  $g.Dispose(); $bmp.Dispose()
  "{0,-11} -> {1} ({2:N0} Ko)" -f $r.Key, $path, ((Get-Item $path).Length / 1KB)
}

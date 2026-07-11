$ErrorActionPreference = 'Stop'
$ip = Get-NetRoute -DestinationPrefix '0.0.0.0/0' |
  Sort-Object RouteMetric, InterfaceMetric |
  ForEach-Object { Get-NetIPAddress -InterfaceIndex $_.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue } |
  Select-Object -First 1 -ExpandProperty IPAddress
if (-not $ip) { throw 'Could not find your Wi-Fi/LAN address.' }

$env:EXPO_PUBLIC_BEERIFY_URL = "http://${ip}:5173"
$vite = Start-Process -FilePath 'npm.cmd' -ArgumentList 'run','dev','--','--host','0.0.0.0' -WorkingDirectory "$PSScriptRoot\.." -WindowStyle Hidden -PassThru

Write-Host "Beerify is available to Expo Go at $env:EXPO_PUBLIC_BEERIFY_URL" -ForegroundColor Green
try { npm.cmd --prefix "$PSScriptRoot\..\expo-go" start }
finally { Stop-Process -Id $vite.Id -Force -ErrorAction SilentlyContinue }

# windows_exporter_setup.ps1
# Scarica e installa windows_exporter come servizio di Windows.
# Richiede privilegi amministrativi.

# Forza TLS 1.2 per il download
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$version = '0.25.1'
$exe = "windows_exporter-$version-amd64.exe"
$url = "https://github.com/prometheus-community/windows_exporter/releases/download/v$version/$exe"

Write-Host "Scarico windows_exporter $version..."
Invoke-WebRequest -Uri $url -OutFile $exe

Write-Host "Installo il servizio windows_exporter..."
& .\$exe install

Write-Host "Avvio il servizio..."
Start-Service windows_exporter

Write-Host "Installazione completata. Il servizio ascoltera' sulla porta 9182."


param(
    [string]$Project = "paper",
    [string]$Version = "",
    [string]$OutFile = "server.jar"
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Api = "https://fill.papermc.io/v3"

function Write-Step($m) { Write-Host "==> $m" -ForegroundColor Cyan }
function Write-Bad($m) { Write-Host "X $m" -ForegroundColor Red }

$javaMajor = $null
try {
    $v = (& java -version 2>&1 | Select-Object -First 1) -replace '"', ""
    if ($v -match "version (\d+)") { $javaMajor = [int]$Matches[1] }
} catch { }
if ($null -eq $javaMajor) {
    Write-Bad "Java not found - install a JDK first (Temurin is free): https://adoptium.net/temurin/releases/"
    exit 1
}
Write-Step "Java major version: $javaMajor"

Write-Step "Reading PaperMC build list..."
$versions = (Invoke-RestMethod -Uri "$Api/projects/$Project/versions?limit=25").versions
$supported = @($versions | Where-Object { $_.version.support.status -eq "SUPPORTED" })
if ($Version -ne "") {
    $chosen = $versions | Where-Object { $_.version.id -eq $Version } | Select-Object -First 1
    if ($null -eq $chosen) { Write-Bad "Version '$Version' not available."; exit 1 }
} else {
    if ($supported.Count -eq 0) { Write-Bad "No supported version found."; exit 1 }
    $chosen = $supported[0]
}
$id = $chosen.version.id
$reqJava = $chosen.java.version.minimum
Write-Step "Latest supported: $id (needs Java >= $reqJava)"
if ($javaMajor -lt $reqJava) {
    Write-Bad "Your Java is $javaMajor but $id needs $reqJava. Install Temurin $reqJava and rerun."
    exit 1
}

$build = $null
foreach ($b in @($chosen.builds | Sort-Object {[int]$_} -Descending)) {
    $info = Invoke-RestMethod -Uri "$Api/projects/$Project/versions/$id/builds/$b"
    if ($info.channel -eq "STABLE") { $build = $info; break }
}
if ($null -eq $build) { Write-Bad "No stable build for $id."; exit 1 }

$dl = $build.downloads."server:default"
Write-Step "Downloading build $($build.id) -> $OutFile ($([math]::Round($dl.size/1MB,1)) MB)"
Invoke-WebRequest -Uri $dl.url -OutFile $OutFile -UseBasicParsing

$actual = (Get-FileHash -Path $OutFile -Algorithm SHA256).Hash.ToLower()
if ($actual -ne $dl.checksums.sha256) {
    Write-Bad "SHA-256 mismatch - deleting download."
    Remove-Item $OutFile -Force
    exit 1
}
Write-Step "Checksum OK."

@"
project=$Project
version=$id
build=$($build.id)
"@ | Set-Content -Path "server.build.properties" -Encoding ASCII

Write-Host ""
Write-Step "DONE. Next: start.ps1"
Write-Host "Now run:  .\start.ps1" -ForegroundColor Green

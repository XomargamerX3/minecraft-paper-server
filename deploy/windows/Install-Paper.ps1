param(
    [int]$MemoryGB = 0,
    [string]$MinecraftVersion = "",
    [switch]$SkipAutoStart
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Root = Split-Path -Parent $PSScriptRoot
$Api = "https://fill.papermc.io/v3"
$Project = "paper"
$JarName = "server.jar"

function Step($m) { Write-Host "==> $m" -ForegroundColor Cyan }
function Bad($m) { Write-Host "X $m" -ForegroundColor Red }
function Info($m) { Write-Host "    $m" -ForegroundColor Gray }

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { Bad "Run PowerShell as Administrator."; exit 1 }

$TotalGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
if ($MemoryGB -le 0) {
    $MemoryGB = $TotalGB - 2
    if ($MemoryGB -lt 2) { $MemoryGB = 2 }
}
Step "Server memory will be ${MemoryGB}GB (machine has ${TotalGB}GB total)"

# ---------------------------------------------------------------- Java
Step "Resolving Paper build and its required Java version"
$versions = (Invoke-RestMethod -Uri "$Api/projects/paper/versions?limit=25").versions
if ($MinecraftVersion -ne "") {
    $chosen = $versions | Where-Object { $_.version.id -eq $MinecraftVersion } | Select-Object -First 1
    if ($null -eq $chosen) { Bad "Version '$MinecraftVersion' not available."; exit 1 }
} else {
    $supported = @($versions | Where-Object { $_.version.support.status -eq "SUPPORTED" })
    if ($supported.Count -eq 0) { Bad "No supported version found."; exit 1 }
    $chosen = $supported[0]
}
$id = $chosen.version.id
$javaMin = $chosen.version.java.version.minimum
Step "Paper for Minecraft $id (needs Java >= $javaMin)"

$JavaRoot = "C:\Program Files\Java"
$JavaHome = Join-Path $JavaRoot "current"
$JavaExe = Join-Path $JavaHome "bin\java.exe"

function Get-JavaMajor($path) {
    if (-not (Test-Path $path)) { return 0 }
    $line = (& $path -version 2>&1 | Select-Object -First 1) -replace '"', ""
    if ($line -match "version (\d+)") { return [int]$Matches[1] }
    return 0
}

if ((Get-JavaMajor $JavaExe) -lt $javaMin) {
    $winArch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "aarch64" } else { "x64" }
    $url = "https://api.adoptium.net/v3/binary/latest/$javaMin/ga/windows/$winArch/jdk/hotspot/normal/eclipse"
    Step "Downloading Temurin JDK $javaMin for $winArch"
    $zip = Join-Path $env:TEMP "temurin.zip"
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
    $extract = Join-Path $env:TEMP "temurin-jdk"
    if (Test-Path $extract) { Remove-Item $extract -Recurse -Force }
    Expand-Archive -Path $zip -DestinationPath $extract -Force
    $inner = Get-ChildItem $extract -Directory | Select-Object -First 1
    if (-not (Test-Path $JavaRoot)) { New-Item -ItemType Directory -Path $JavaRoot | Out-Null }
    if (Test-Path $JavaHome) { cmd /c "rmdir /s /q `"$JavaHome`"" }
    Move-Item $inner.FullName (Join-Path $JavaRoot ("temurin-$javaMin"))
    cmd /c "mklink /J `"$JavaHome`" `"$JavaRoot\temurin-$javaMin`"" | Out-Null
    Remove-Item $zip -Force
    [Environment]::SetEnvironmentVariable("JAVA_HOME", $JavaHome, "Machine")
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($machinePath -notlike "*$JavaHome\bin*") {
        [Environment]::SetEnvironmentVariable("Path", "$machinePath;$JavaHome\bin", "Machine")
    }
    Info "Installed to $JavaHome"
} else {
    Info "Java $javaMin already present"
}
if ((Get-JavaMajor $JavaExe) -lt $javaMin) { Bad "Java install failed."; exit 1 }

# ---------------------------------------------------------------- Paper
$build = $null
foreach ($b in @($chosen.builds | Sort-Object {[int]$_} -Descending)) {
    $info = Invoke-RestMethod -Uri "$Api/projects/$Project/versions/$id/builds/$b" -ErrorAction Stop
    if ($info.channel -eq "STABLE") { $build = $info; break }
}
if ($null -eq $build) { Bad "No stable build for $id."; exit 1 }
$dl = $build.downloads."server:default"
$jar = Join-Path $Root $JarName

$needDownload = $true
if (Test-Path $jar) {
    $have = (Get-FileHash -Path $jar -Algorithm SHA256).Hash.ToLower()
    if ($have -eq $dl.checksums.sha256) {
        $needDownload = $false
        Info "server.jar already present and verified"
    }
}
if ($needDownload) {
    Step "Downloading build $($build.id) ($([math]::Round($dl.size/1MB,1)) MB)"
    Invoke-WebRequest -Uri $dl.url -OutFile "$jar.part" -UseBasicParsing
    $got = (Get-FileHash -Path "$jar.part" -Algorithm SHA256).Hash.ToLower()
    if ($got -ne $dl.checksums.sha256) {
        Remove-Item "$jar.part" -Force
        Bad "SHA-256 mismatch - download corrupt."
        exit 1
    }
    Move-Item "$jar.part" $jar -Force
}
@"
project=paper
version=$id
build=$($build.id)
"@ | Set-Content -Path (Join-Path $Root "server.build.properties") -Encoding ASCII

# ---------------------------------------------------------------- Firewall
Step "Opening TCP 25565 in Windows Firewall"
$rule = Get-NetFirewallRule -DisplayName "Minecraft Paper 25565" -ErrorAction SilentlyContinue
if ($null -eq $rule) {
    New-NetFirewallRule -DisplayName "Minecraft Paper 25565" -Direction Inbound -Protocol TCP `
        -LocalPort 25565 -Action Allow -Profile Any | Out-Null
    Info "Rule created"
} else {
    Info "Rule already exists"
}

# ---------------------------------------------------------------- Auto start
if (-not $SkipAutoStart) {
    Step "Registering the startup task (restarts after reboot, and after crashes)"
    $startPs = Join-Path $Root "start.ps1"
    $action = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$startPs`" -MemoryGB $MemoryGB" `
        -WorkingDirectory $Root
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -StartWhenAvailable -ExecutionTimeLimit ([TimeSpan]::Zero) `
        -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
    Register-ScheduledTask -TaskName "PaperMinecraftServer" -Action $action -Trigger $trigger `
        -Settings $settings -User "SYSTEM" -RunLevel Highest -Force | Out-Null
    Info "Task 'PaperMinecraftServer' registered. Manage it with: Get-ScheduledTask -TaskName PaperMinecraftServer"
}

Write-Host ""
Step "Everything is installed."
Write-Host "  1. Read https://www.minecraft.net/en-us/eula and set eula=true in eula.txt yourself" -ForegroundColor Yellow
Write-Host "  2. Start with:  $Root\start.ps1 -MemoryGB $MemoryGB" -ForegroundColor Yellow
Write-Host "  3. Give friends this address (public IP of the VM): <IP>:25565" -ForegroundColor Yellow
Write-Host "  NOTE: cloud provider firewall/Security Group must also allow TCP 25565 - Windows Firewall is only half of it."

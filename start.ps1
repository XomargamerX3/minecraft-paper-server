param(
    [int]$MemoryGB = 6,
    [string]$Jar = "server.jar"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $Jar)) {
    Write-Host "X $Jar not found. Run .\setup.ps1 first." -ForegroundColor Red
    exit 1
}
if (Test-Path "eula.txt") {
    $eula = Get-Content "eula.txt" | Where-Object { $_ -match "^eula=" }
    if ($eula -notmatch "true") {
        Write-Host "X EULA not accepted. Open eula.txt, read https://www.minecraft.net/en-us/eula" -ForegroundColor Red
        Write-Host "  then set eula=true and run this script again." -ForegroundColor Red
        exit 1
    }
}

$flags = @(
    "-Xms${MemoryGB}g", "-Xmx${MemoryGB}g",
    "-XX:+UseG1GC", "-XX:+ParallelRefProcEnabled", "-XX:MaxGCPauseMillis=200",
    "-XX:+UnlockExperimentalVMOptions", "-XX:+DisableExplicitGC", "-XX:+AlwaysPreTouch",
    "-XX:G1NewSizePercent=30", "-XX:G1MaxNewSizePercent=40", "-XX:G1HeapRegionSize=8M",
    "-XX:G1ReservePercent=20", "-XX:G1HeapWastePercent=5", "-XX:G1MixedGCCountTarget=4",
    "-XX:InitiatingHeapOccupancyPercent=15", "-XX:G1MixedGCLiveThresholdPercent=90",
    "-XX:G1RSetUpdatingPauseTimePercent=5", "-XX:SurvivorRatio=32", "-XX:+PerfDisableSharedMem",
    "-XX:MaxTenuringThreshold=1", "-Dusing.aikars.flags=https://mcflags.emc.gs",
    "-Daikars.new.flags=true", "-jar", $Jar, "nogui"
)

Write-Host "==> Starting Paper with ${MemoryGB}GB RAM. Type 'stop' in this window to shut down cleanly." -ForegroundColor Cyan
& java @flags

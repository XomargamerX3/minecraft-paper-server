#!/usr/bin/env bash
# Starts Paper in the foreground inside a Codespace, so the terminal stays your server console.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MEMORY_MB="${MEMORY_MB:-6144}"
JAVA_BIN="${JAVA_BIN:-/opt/java/current/bin/java}"

die() { printf '\e[31mX %s\e[0m\n' "$*" >&2; exit 1; }

cd "$REPO_DIR"
[ -x "$JAVA_BIN" ] || die "No Java yet - run: bash .devcontainer/onCreate.sh"
[ -f server.jar ] || die "No server.jar yet - run: bash .devcontainer/onCreate.sh"
grep -qs "^eula=true" eula.txt || die "Read https://www.minecraft.net/en-us/eula then run: echo 'eula=true' > eula.txt"

exec "$JAVA_BIN" -Xms"${MEMORY_MB}m" -Xmx"${MEMORY_MB}m" \
  -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 \
  -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch \
  -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M \
  -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 \
  -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 \
  -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem \
  -XX:MaxTenuringThreshold=1 \
  -jar server.jar nogui

#!/usr/bin/env bash
# Runs inside the GitHub Codespace: installs a JDK and downloads Paper into the repo.
# No EULA acceptance happens here on purpose - that stays a human decision.
set -euo pipefail

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../deploy" && pwd)"
REPO_DIR="$(dirname "$DEPLOY_DIR")"
PAPER_API="https://fill.papermc.io/v3"
MINECRAFT_VERSION="${MINECRAFT_VERSION:-}"

log() { printf '\e[36m==>\e[0m %s\n' "$*"; }
die() { printf '\e[31mX %s\e[0m\n' "$*" >&2; exit 1; }

log "Installing curl, python3, ca-certificates"
sudo apt-get update -qq
sudo apt-get install -y -qq curl ca-certificates python3

log "Resolving the newest stable Paper build"
OUT="$(mktemp)"
python3 "$DEPLOY_DIR/resolve_paper.py" "$PAPER_API" "$MINECRAFT_VERSION" > "$OUT" \
  || die "Could not reach the PaperMC API"
while IFS='=' read -r key value; do
  case "$key" in
    MC_VERSION) MC_VERSION="$value" ;;
    JAVA_MIN) JAVA_MIN="$value" ;;
    BUILD) BUILD="$value" ;;
    DOWNLOAD_URL) DOWNLOAD_URL="$value" ;;
    DOWNLOAD_SHA) DOWNLOAD_SHA="$value" ;;
  esac
done < "$OUT"
rm -f "$OUT"
log "Minecraft $MC_VERSION, Paper build $BUILD, needs Java >= $JAVA_MIN"

JAVA_BIN=/opt/java/current/bin/java
major=0
if [ -x "$JAVA_BIN" ]; then
  major="$("$JAVA_BIN" -version 2>&1 | head -1 | sed -E 's/.*version "([0-9]+).*/\1/')"
  [[ "$major" =~ ^[0-9]+$ ]] || major=0
fi
if [ ! -x "$JAVA_BIN" ] || [ "$major" -lt "$JAVA_MIN" ]; then
  log "Installing Temurin JDK $JAVA_MIN"
  TMP="/opt/java/tmp.$$"
  sudo mkdir -p "$TMP"
  curl -fL --retry 3 -o /tmp/jdk.tar.gz \
    "https://api.adoptium.net/v3/binary/latest/${JAVA_MIN}/ga/linux/x64/jdk/hotspot/normal/eclipse"
  sudo tar -xzf /tmp/jdk.tar.gz -C "$TMP" --strip-components=1
  sudo rm -rf /opt/java/current /opt/java/jdk
  sudo mv "$TMP" /opt/java/jdk
  sudo ln -s /opt/java/jdk /opt/java/current
  sudo rm -f /tmp/jdk.tar.gz
  log "Java: $("$JAVA_BIN" -version 2>&1 | head -1)"
else
  log "Java $JAVA_MIN already installed"
fi

JAR="$REPO_DIR/server.jar"
if [ -f "$JAR" ] && [ "$(sha256sum "$JAR" | cut -d' ' -f1)" = "$DOWNLOAD_SHA" ]; then
  log "server.jar already present and verified"
else
  log "Downloading Paper build $BUILD"
  curl -fL --retry 3 -o "$JAR.part" "$DOWNLOAD_URL"
  echo "$DOWNLOAD_SHA  $JAR.part" | sha256sum -c - >/dev/null ||
    { rm -f "$JAR.part"; die "Checksum mismatch"; }
  mv "$JAR.part" "$JAR"
fi
printf 'project=paper\nversion=%s\nbuild=%s\n' "$MC_VERSION" "$BUILD" > "$REPO_DIR/server.build.properties"

log "Ready. Next steps inside this codespace terminal:"
printf '  1. read https://www.minecraft.net/en-us/eula then: echo "eula=true" > %s/eula.txt\n' "$REPO_DIR"
printf '  2. cd %s && bash deploy/codespaces-run.sh\n' "$REPO_DIR"

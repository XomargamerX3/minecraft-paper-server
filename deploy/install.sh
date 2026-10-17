#!/usr/bin/env bash
# One-shot installer for a Paper Minecraft server on an Oracle Cloud free VM.
# Run as root on Ubuntu 22.04 / 24.04. Idempotent: safe to re-run.
#
#   sudo bash install.sh
#   MINECRAFT_VERSION=1.21.4 sudo -E bash install.sh
#   MEMORY_MB=12288 sudo -E bash install.sh
set -euo pipefail

APP_DIR="${APP_DIR:-/srv/minecraft/paper}"
RUN_USER="${RUN_USER:-minecraft}"
MEMORY_MB="${MEMORY_MB:-8192}"
MINECRAFT_VERSION="${MINECRAFT_VERSION:-}"
SERVER_PORT="${SERVER_PORT:-25565}"
PAPER_API="https://fill.papermc.io/v3"
DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$DEPLOY_DIR")"

log() { printf '\e[36m==>\e[0m %s\n' "$*"; }
die() { printf '\e[31mX %s\e[0m\n' "$*" >&2; exit 1; }
java_major() {
  "$1" -version 2>&1 | head -1 | sed -E 's/.*version "([0-9]+).*/\1/'
}

[ "$(id -u)" -eq 0 ] || die "Run as root: sudo bash install.sh"

log "Installing base packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl ca-certificates python3 iptables netfilter-persistent

ARCH="$(dpkg --print-architecture)"
case "$ARCH" in
  arm64) JAVA_ARCH=aarch64 ;;
  amd64) JAVA_ARCH=x64 ;;
  *) die "Unsupported CPU architecture: $ARCH" ;;
esac

log "Resolving the newest stable Paper build"
RESOLVE_OUT="$(mktemp)"
python3 "$DEPLOY_DIR/resolve_paper.py" "$PAPER_API" "$MINECRAFT_VERSION" > "$RESOLVE_OUT" \
  || die "Could not reach the PaperMC API (check DNS/outbound network)"
while IFS='=' read -r key value; do
  case "$key" in
    MC_VERSION) MC_VERSION="$value" ;;
    JAVA_MIN) JAVA_MIN="$value" ;;
    BUILD) BUILD="$value" ;;
    DOWNLOAD_URL) DOWNLOAD_URL="$value" ;;
    DOWNLOAD_SHA) DOWNLOAD_SHA="$value" ;;
  esac
done < "$RESOLVE_OUT"
rm -f "$RESOLVE_OUT"
[ -n "${DOWNLOAD_SHA:-}" ] || die "PaperMC API returned no checksum"
log "Paper for Minecraft $MC_VERSION, build $BUILD (needs Java >= $JAVA_MIN)"

JAVA_BIN=/opt/java/current/bin/java
if [ ! -x "$JAVA_BIN" ] || [ "$(java_major "$JAVA_BIN")" -lt "$JAVA_MIN" ]; then
  log "Installing Temurin JDK $JAVA_MIN"
  TMP_DIR="/opt/java/tmp.$$"
  mkdir -p "$TMP_DIR"
  curl -fL --retry 3 -o /tmp/jdk.tar.gz \
    "https://api.adoptium.net/v3/binary/latest/${JAVA_MIN}/ga/linux/${JAVA_ARCH}/jdk/hotspot/normal/eclipse"
  tar -xzf /tmp/jdk.tar.gz -C "$TMP_DIR" --strip-components=1
  rm -rf /opt/java/current /opt/java/jdk
  mv "$TMP_DIR" /opt/java/jdk
  ln -s /opt/java/jdk /opt/java/current
  rm -f /tmp/jdk.tar.gz
  log "Java is now: $("$JAVA_BIN" -version 2>&1 | head -1)"
else
  log "Java $JAVA_MIN already installed"
fi

log "Creating service user and $APP_DIR"
id -u "$RUN_USER" >/dev/null 2>&1 ||
  useradd --system --home "$APP_DIR" --shell /usr/sbin/nologin --create-home "$RUN_USER"
mkdir -p "$APP_DIR"

if [ -f "$APP_DIR/server.jar" ] &&
   [ "$(sha256sum "$APP_DIR/server.jar" | cut -d' ' -f1)" = "$DOWNLOAD_SHA" ]; then
  log "server.jar already present and verified"
else
  log "Downloading Paper jar"
  curl -fL --retry 3 -o "$APP_DIR/server.jar.part" "$DOWNLOAD_URL"
  echo "$DOWNLOAD_SHA  $APP_DIR/server.jar.part" | sha256sum -c - >/dev/null ||
    { rm -f "$APP_DIR/server.jar.part"; die "Checksum mismatch - download is corrupt"; }
  mv "$APP_DIR/server.jar.part" "$APP_DIR/server.jar"
fi
printf 'project=paper\nversion=%s\nbuild=%s\n' "$MC_VERSION" "$BUILD" > "$APP_DIR/server.build.properties"

if [ ! -f "$APP_DIR/server.properties" ]; then
  log "Copying server.properties from the repo"
  cp "$REPO_DIR/server.properties" "$APP_DIR/"
fi
if [ ! -d "$APP_DIR/plugins" ]; then
  mkdir -p "$APP_DIR/plugins"
  cp "$REPO_DIR/plugins/README.md" "$APP_DIR/plugins/" 2>/dev/null || true
fi

# The EULA is a legal agreement with Mojang, so a human has to accept it, not this script.
if ! grep -qs "^eula=true" "$APP_DIR/eula.txt"; then
  log "EULA not accepted - finish with this after reading https://www.minecraft.net/en-us/eula :"
  printf '\e[33m  sudo bash -c "echo eula=true > %s/eula.txt && chown %s: %s/eula.txt && systemctl restart paper"\e[0m\n' \
    "$APP_DIR" "$RUN_USER" "$APP_DIR"
  START_NOW=false
else
  START_NOW=true
fi

log "Installing the systemd unit"
sed -e "s|__APP_DIR__|$APP_DIR|g" \
    -e "s|__RUN_USER__|$RUN_USER|g" \
    -e "s|__JAVA_BIN__|$JAVA_BIN|g" \
    -e "s|__MEMORY_MB__|$MEMORY_MB|g" \
    -e "s|__SERVER_PORT__|$SERVER_PORT|g" \
    "$DEPLOY_DIR/paper.service" > /etc/systemd/system/paper.service
chmod 644 /etc/systemd/system/paper.service
chown -R "$RUN_USER:$RUN_USER" "$APP_DIR"
systemctl daemon-reload
systemctl enable paper >/dev/null

log "Opening TCP/$SERVER_PORT in the local firewall"
if ! iptables -S INPUT | grep -q -- "--dport $SERVER_PORT -j ACCEPT"; then
  iptables -I INPUT 1 -p tcp --dport "$SERVER_PORT" -j ACCEPT \
    -m comment --comment minecraft-paper
  netfilter-persistent save >/dev/null 2>&1 || true
fi

if [ "$START_NOW" = true ]; then
  systemctl restart paper
  sleep 3
  systemctl --no-pager --lines=15 status paper || true
fi

log "Console / logs:  journalctl -u paper -f"
log "Status:          systemctl status paper"
log "Restart:         sudo systemctl restart paper"
log "Address to type in Minecraft: <public IP>:$SERVER_PORT"
log "Still required in the Oracle web console: ingress rule TCP $SERVER_PORT (see deploy/ORACLE-SETUP.md)"

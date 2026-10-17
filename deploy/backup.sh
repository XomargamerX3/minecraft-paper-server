#!/usr/bin/env bash
# Snapshot the world into /srv/minecraft/backups, keeping the newest 14.
# The server stops for a few seconds so the copy is consistent.
set -euo pipefail

APP_DIR="${APP_DIR:-/srv/minecraft/paper}"
BACKUP_DIR="${BACKUP_DIR:-/srv/minecraft/backups}"
KEEP="${KEEP:-14}"
SERVICE="${SERVICE:-paper}"

log() { printf '\e[36m==>\e[0m %s\n' "$*"; }
die() { printf '\e[31mX %s\e[0m\n' "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "Run as root"
[ -d "$APP_DIR/world" ] || die "No world folder in $APP_DIR yet - start the server once first"

mkdir -p "$BACKUP_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"

log "Stopping $SERVICE (players get kicked)"
systemctl stop "$SERVICE"

log "Archiving to $BACKUP_DIR/world-$STAMP.tar.gz"
tar -czf "$BACKUP_DIR/world-$STAMP.tar.gz" -C "$APP_DIR" \
  world server.properties plugins 2>/dev/null
chmod 640 "$BACKUP_DIR/world-$STAMP.tar.gz"

log "Restarting $SERVICE"
systemctl start "$SERVICE"

log "Pruning old backups (keeping $KEEP)"
ls -1t "$BACKUP_DIR"/world-*.tar.gz 2>/dev/null | tail -n +$((KEEP + 1)) |
  while read -r old; do rm -f "$old"; done

log "DONE. Restore a snapshot with:"
printf '  systemctl stop %s\n  rm -rf %s/world\n  tar -xzf %s/world-%s.tar.gz -C %s\n  systemctl start %s\n' \
  "$SERVICE" "$APP_DIR" "$BACKUP_DIR" "$STAMP" "$APP_DIR" "$SERVICE"

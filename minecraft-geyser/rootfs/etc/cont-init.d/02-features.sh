#!/usr/bin/env bash
# Wires HA addon options into Paper plugin URLs and per-plugin config.
# Runs after 00-global_var.sh exports options as env vars, before run.sh
# launches itzg's /start.

set -u

log() { echo "[features] $*"; }

# ---- BlueMap (3D map viewer, served via HA Ingress on 8100) ----
BLUEMAP_ENABLED="${BLUEMAP_ENABLED:-true}"
BLUEMAP_VERSION="${BLUEMAP_VERSION:-5.20}"

# ---- DriveBackupV2 (backups to /media/minecraft-backups) ----
BACKUP_ENABLED="${BACKUP_ENABLED:-true}"
BACKUP_DELAY_MINUTES="${BACKUP_DELAY_MINUTES:-1440}"
BACKUP_KEEP_COUNT="${BACKUP_KEEP_COUNT:-7}"
BACKUP_DEST="/media/minecraft-backups"
DRIVEBACKUP_VERSION="1.8.1"

append_plugin() {
    local url="$1"
    if [ -n "${PLUGINS:-}" ]; then
        PLUGINS="${PLUGINS},${url}"
    else
        PLUGINS="${url}"
    fi
}

if [ "${BLUEMAP_ENABLED,,}" = "true" ]; then
    append_plugin "https://github.com/BlueMap-Minecraft/BlueMap/releases/download/v${BLUEMAP_VERSION}/bluemap-${BLUEMAP_VERSION}-paper.jar"
    log "BlueMap ${BLUEMAP_VERSION} queued for install"
fi

if [ "${BACKUP_ENABLED,,}" = "true" ]; then
    append_plugin "https://github.com/MaxMaeder/DriveBackupV2/releases/download/v${DRIVEBACKUP_VERSION}/DriveBackupV2.jar"
    mkdir -p "${BACKUP_DEST}"

    # Seed DriveBackupV2 config on first run only — preserves user edits.
    plugin_cfg_dir="/data/plugins/DriveBackupV2"
    plugin_cfg="${plugin_cfg_dir}/config.yml"
    if [ ! -f "${plugin_cfg}" ]; then
        mkdir -p "${plugin_cfg_dir}"
        cat > "${plugin_cfg}" <<EOF
delay: ${BACKUP_DELAY_MINUTES}
keep-count: ${BACKUP_KEEP_COUNT}
local-keep-count: ${BACKUP_KEEP_COUNT}
local-save-directory: "${BACKUP_DEST}"
backups-require-players: false
backup-list:
  - path: "world"
    glob: false
    format: "world-%FORMAT.zip"
    create: true
  - path: "world_nether"
    glob: false
    format: "world_nether-%FORMAT.zip"
    create: true
  - path: "world_the_end"
    glob: false
    format: "world_the_end-%FORMAT.zip"
    create: true
EOF
        log "Seeded DriveBackupV2 config -> ${BACKUP_DEST} every ${BACKUP_DELAY_MINUTES} min, keep ${BACKUP_KEEP_COUNT}"
    else
        log "DriveBackupV2 config already exists; not overwriting"
    fi
fi

# Re-export PLUGINS so itzg's /start (and s6 services, if any) see updates.
export PLUGINS
if [ -d /var/run/s6/container_environment ]; then
    printf '%s' "${PLUGINS}" > /var/run/s6/container_environment/PLUGINS
fi

log "PLUGINS set (${#PLUGINS} chars)"

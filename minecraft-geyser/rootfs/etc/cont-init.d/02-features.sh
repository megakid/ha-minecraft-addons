#!/usr/bin/env bash
set -u

log() { echo "[features] $*"; }

PLUGINS="${PLUGINS-}"
BACKUP_DEST="/media/minecraft-backups"
DRIVEBACKUP_VERSION="1.8.1"

append_plugin() {
    local url="$1"
    if [ -n "${PLUGINS-}" ]; then
        PLUGINS="${PLUGINS},${url}"
    else
        PLUGINS="${url}"
    fi
}

if [ "${BLUEMAP_ENABLED-}" = "true" ]; then
    append_plugin "https://github.com/BlueMap-Minecraft/BlueMap/releases/download/v${BLUEMAP_VERSION}/bluemap-${BLUEMAP_VERSION}-paper.jar"
    log "BlueMap ${BLUEMAP_VERSION} queued for install"

    # BlueMap requires the user to accept downloading client resources (similar
    # to EULA). Seed the accept on first run; user opted in by enabling it.
    bluemap_cfg_dir="/data/plugins/BlueMap"
    bluemap_cfg="${bluemap_cfg_dir}/core.conf"
    if [ ! -f "${bluemap_cfg}" ]; then
        mkdir -p "${bluemap_cfg_dir}"
        echo "accept-download: true" > "${bluemap_cfg}"
        log "Seeded BlueMap core.conf with accept-download: true"
    fi
fi

if [ "${BACKUP_ENABLED-}" = "true" ]; then
    append_plugin "https://github.com/MaxMaeder/DriveBackupV2/releases/download/v${DRIVEBACKUP_VERSION}/DriveBackupV2.jar"
    mkdir -p "${BACKUP_DEST}"

    plugin_cfg_dir="/data/plugins/DriveBackupV2"
    plugin_cfg="${plugin_cfg_dir}/config.yml"
    # Seed once — subsequent boots leave the user's edits alone.
    if [ ! -f "${plugin_cfg}" ]; then
        level="${LEVEL-world}"
        mkdir -p "${plugin_cfg_dir}"
        cat > "${plugin_cfg}" <<EOF
delay: ${BACKUP_DELAY_MINUTES}
keep-count: ${BACKUP_KEEP_COUNT}
local-keep-count: ${BACKUP_KEEP_COUNT}
local-save-directory: "${BACKUP_DEST}"
backups-require-players: false
backup-list:
  - glob: "${level}*"
    format: "%NAME-%FORMAT.zip"
    create: true
EOF
        log "Seeded DriveBackupV2 config -> ${BACKUP_DEST} every ${BACKUP_DELAY_MINUTES} min, keep ${BACKUP_KEEP_COUNT}"
    else
        log "DriveBackupV2 config already exists; not overwriting"
    fi
fi

# Sibling s6 services read env from /var/run/s6/container_environment, not from
# our shell — so write the file too, not just export.
export PLUGINS
if [ -d /var/run/s6/container_environment ]; then
    printf '%s' "${PLUGINS}" > /var/run/s6/container_environment/PLUGINS
fi

log "PLUGINS set (${#PLUGINS} chars)"

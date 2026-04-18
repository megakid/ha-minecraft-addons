#!/usr/bin/env bash
set -u

log() { echo "[features] $*"; }

BACKUP_DEST="/media/minecraft-backups"
DRIVEBACKUP_VERSION="1.8.1"
PLUGINS_DIR="/data/plugins"

# Download a plugin jar straight into /data/plugins, bypassing itzg's PLUGINS
# env-var pipeline. The alexbelgium template injects the original PLUGINS value
# into every cont-init.d script at boot, which clobbers any modification we
# make here — so we install the jars directly instead.
fetch_plugin() {
    local url="$1" name="$2"
    local dest="${PLUGINS_DIR}/${name}"
    if [ -f "${dest}" ]; then
        log "${name} already present"
        return 0
    fi
    mkdir -p "${PLUGINS_DIR}"
    log "Downloading ${name}..."
    if curl -fsSL --retry 3 -o "${dest}.tmp" "${url}"; then
        mv "${dest}.tmp" "${dest}"
        log "Installed ${name}"
    else
        rm -f "${dest}.tmp"
        log "ERROR: failed to download ${name} from ${url}"
        return 1
    fi
}

# Drop any leftover jars whose filename matches the pattern but not the wanted
# version, so toggling BLUEMAP_VERSION cleans up older copies on next boot.
prune_other_versions() {
    local pattern="$1" keep="$2"
    find "${PLUGINS_DIR}" -maxdepth 1 -name "${pattern}" ! -name "${keep}" -type f -delete 2>/dev/null || true
}

if [ "${BLUEMAP_ENABLED-}" = "true" ]; then
    bluemap_jar="bluemap-${BLUEMAP_VERSION}-paper.jar"
    prune_other_versions "bluemap-*-paper.jar" "${bluemap_jar}"
    fetch_plugin "https://github.com/BlueMap-Minecraft/BlueMap/releases/download/v${BLUEMAP_VERSION}/${bluemap_jar}" "${bluemap_jar}"

    # BlueMap requires the user to accept downloading client resources (similar
    # to EULA). Seed the accept on first run; user opted in by enabling it.
    bluemap_cfg_dir="/data/plugins/BlueMap"
    bluemap_cfg="${bluemap_cfg_dir}/core.conf"
    if [ ! -f "${bluemap_cfg}" ]; then
        mkdir -p "${bluemap_cfg_dir}"
        echo "accept-download: true" > "${bluemap_cfg}"
        log "Seeded BlueMap core.conf with accept-download: true"
    fi
else
    prune_other_versions "bluemap-*-paper.jar" ""
fi

if [ "${BACKUP_ENABLED-}" = "true" ]; then
    fetch_plugin "https://github.com/MaxMaeder/DriveBackupV2/releases/download/v${DRIVEBACKUP_VERSION}/DriveBackupV2.jar" "DriveBackupV2.jar"
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
else
    rm -f "${PLUGINS_DIR}/DriveBackupV2.jar" 2>/dev/null
fi

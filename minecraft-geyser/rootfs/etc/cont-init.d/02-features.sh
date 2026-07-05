#!/usr/bin/env bash
set -u

log() { echo "[features] $*"; }

BACKUP_DEST="${BACKUP_DEST:-/media/minecraft-backups}"
SERVER_DIR="${SERVER_DIR:-/data}"
BACKUP_LOCAL_DIR="${BACKUP_LOCAL_DIR:-minecraft-backups}"
BACKUP_LINK="${BACKUP_LINK:-${SERVER_DIR}/${BACKUP_LOCAL_DIR}}"
DRIVEBACKUP_VERSION="${DRIVEBACKUP_VERSION:-1.8.1}"
PLUGINS_DIR="${PLUGINS_DIR:-/data/plugins}"

# itzg drops to this uid:gid before running the server. Anything we create
# while still root needs to be handed over or the server cannot write to it.
SERVER_UID="${UID:-1000}"
SERVER_GID="${GID:-1000}"

ensure_owned_dir() {
    local dir="$1"
    mkdir -p "${dir}"
    chown -R "${SERVER_UID}:${SERVER_GID}" "${dir}" 2>/dev/null || true
}

ensure_backup_target() {
    ensure_owned_dir "${BACKUP_DEST}"
    if [ -L "${BACKUP_LINK}" ] || [ ! -e "${BACKUP_LINK}" ]; then
        ln -sfn "${BACKUP_DEST}" "${BACKUP_LINK}"
    else
        log "${BACKUP_LINK} already exists; not replacing it with a symlink"
    fi
}

# Download a plugin jar straight into PLUGINS_DIR, bypassing itzg's PLUGINS
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

set_yaml_scalar() {
    local file="$1" key="$2" value="$3" tmp="${file}.tmp"
    awk -v key="${key}" -v value="${value}" '
        $0 ~ "^" key ":" {
            print key ": " value
            found = 1
            next
        }
        { print }
        END {
            if (!found) {
                print key ": " value
            }
        }
    ' "${file}" > "${tmp}" && mv "${tmp}" "${file}"
}

remove_legacy_plugin_backup_stanza() {
    local file="$1" tmp="${file}.tmp"
    awk '
        skipping && $0 ~ /^[^[:space:]-]/ {
            skipping = 0
        }
        skipping && $0 ~ /^[[:space:]]*-[[:space:]]/ {
            skipping = 0
        }
        !skipping && $0 ~ /^[[:space:]]*-[[:space:]]*path:[[:space:]]*"?plugins"?[[:space:]]*$/ {
            skipping = 1
            next
        }
        skipping {
            next
        }
        { print }
    ' "${file}" > "${tmp}" && mv "${tmp}" "${file}"
}

backup_config_needs_migration() {
    local file="$1"
    grep -Eq '^local-save-directory:[[:space:]]*"?backups"?[[:space:]]*$' "${file}" && return 0
    grep -Eq '^local-keep-count:[[:space:]]*0[[:space:]]*$' "${file}" && return 0
    grep -Eq '^[[:space:]]*-[[:space:]]*path:[[:space:]]*"?plugins"?[[:space:]]*$' "${file}" && return 0
    return 1
}

migrate_backup_config() {
    local file="$1"

    if ! backup_config_needs_migration "${file}"; then
        log "DriveBackupV2 config already exists; not overwriting"
        return 0
    fi

    log "Migrating DriveBackupV2 config to bounded ${BACKUP_DEST} backups"
    set_yaml_scalar "${file}" "delay" "${BACKUP_DELAY_MINUTES}"
    set_yaml_scalar "${file}" "keep-count" "${BACKUP_KEEP_COUNT}"
    set_yaml_scalar "${file}" "local-keep-count" "${BACKUP_KEEP_COUNT}"
    set_yaml_scalar "${file}" "local-save-directory" "\"${BACKUP_LOCAL_DIR}\""
    set_yaml_scalar "${file}" "backups-require-players" "false"
    remove_legacy_plugin_backup_stanza "${file}"
}

if [ "${BLUEMAP_ENABLED-}" = "true" ]; then
    bluemap_jar="bluemap-${BLUEMAP_VERSION}-paper.jar"
    prune_other_versions "bluemap-*-paper.jar" "${bluemap_jar}"
    fetch_plugin "https://github.com/BlueMap-Minecraft/BlueMap/releases/download/v${BLUEMAP_VERSION}/${bluemap_jar}" "${bluemap_jar}"

    # BlueMap requires the user to accept downloading client resources (similar
    # to EULA). Seed the accept on first run; user opted in by enabling it.
    bluemap_cfg_dir="${PLUGINS_DIR}/BlueMap"
    bluemap_cfg="${bluemap_cfg_dir}/core.conf"
    if [ ! -f "${bluemap_cfg}" ]; then
        mkdir -p "${bluemap_cfg_dir}"
        echo "accept-download: true" > "${bluemap_cfg}"
        log "Seeded BlueMap core.conf with accept-download: true"
    fi
    ensure_owned_dir "${bluemap_cfg_dir}"
else
    prune_other_versions "bluemap-*-paper.jar" ""
fi

if [ "${BACKUP_ENABLED-}" = "true" ]; then
    fetch_plugin "https://github.com/MaxMaeder/DriveBackupV2/releases/download/v${DRIVEBACKUP_VERSION}/DriveBackupV2.jar" "DriveBackupV2.jar"
    ensure_backup_target

    plugin_cfg_dir="${PLUGINS_DIR}/DriveBackupV2"
    plugin_cfg="${plugin_cfg_dir}/config.yml"
    if [ ! -f "${plugin_cfg}" ]; then
        level="${LEVEL-world}"
        mkdir -p "${plugin_cfg_dir}"
        cat > "${plugin_cfg}" <<EOF
delay: ${BACKUP_DELAY_MINUTES}
keep-count: ${BACKUP_KEEP_COUNT}
local-keep-count: ${BACKUP_KEEP_COUNT}
local-save-directory: "${BACKUP_LOCAL_DIR}"
backups-require-players: false
backup-list:
  - glob: "${level}*"
    format: "%NAME-%FORMAT.zip"
    create: true
EOF
        log "Seeded DriveBackupV2 config -> ${BACKUP_DEST} every ${BACKUP_DELAY_MINUTES} min, keep ${BACKUP_KEEP_COUNT}"
    else
        migrate_backup_config "${plugin_cfg}"
    fi
    ensure_owned_dir "${plugin_cfg_dir}"
else
    rm -f "${PLUGINS_DIR}/DriveBackupV2.jar" 2>/dev/null
fi

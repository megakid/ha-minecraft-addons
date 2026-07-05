#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
features_script="${repo_root}/minecraft-geyser/rootfs/etc/cont-init.d/02-features.sh"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

export PATH="${tmp_dir}/bin:${PATH}"
mkdir -p "${tmp_dir}/bin"
cat > "${tmp_dir}/bin/curl" <<'STUB'
#!/usr/bin/env bash
echo "unexpected curl invocation" >&2
exit 1
STUB
chmod +x "${tmp_dir}/bin/curl"

export PLUGINS_DIR="${tmp_dir}/data/plugins"
export BACKUP_DEST="${tmp_dir}/media/minecraft-backups"
export SERVER_DIR="${tmp_dir}/data"
export BLUEMAP_ENABLED=false
export BACKUP_ENABLED=true
export BACKUP_DELAY_MINUTES=1440
export BACKUP_KEEP_COUNT=7
export LEVEL=world

mkdir -p "${PLUGINS_DIR}/DriveBackupV2"
touch "${PLUGINS_DIR}/DriveBackupV2.jar"

cat > "${PLUGINS_DIR}/DriveBackupV2/config.yml" <<'CONFIG'
version: 2

delay: 60
backup-thread-priority: 1
keep-count: 20
local-keep-count: 0
zip-compression: 1
backups-require-players: true
disable-saving-during-backups: true

scheduled-backups: false
backup-schedule-list:

backup-list:
- glob: "world*"
  format: "Backup-%NAME-%FORMAT.zip"
  create: true
- path: "plugins"
  format: "Backup-plugins-%FORMAT.zip"
  create: true

external-backup-list:

local-save-directory: "backups"
remote-save-directory: "backups"
CONFIG

bash "${features_script}" > "${tmp_dir}/features.log"

config="${PLUGINS_DIR}/DriveBackupV2/config.yml"

grep -Fq 'delay: 1440' "${config}"
grep -Fq 'keep-count: 7' "${config}"
grep -Fq 'local-keep-count: 7' "${config}"
grep -Fq 'local-save-directory: "minecraft-backups"' "${config}"
test -L "${SERVER_DIR}/minecraft-backups"
test "$(readlink "${SERVER_DIR}/minecraft-backups")" = "${BACKUP_DEST}"

if grep -Fq 'path: "plugins"' "${config}"; then
    echo "legacy plugins backup stanza was not removed" >&2
    exit 1
fi

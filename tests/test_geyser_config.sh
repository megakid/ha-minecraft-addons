#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
geyser_script="${repo_root}/minecraft-geyser/rootfs/etc/cont-init.d/03-geyser.sh"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

export PATH="${tmp_dir}/bin:${PATH}"
mkdir -p "${tmp_dir}/bin"

# The Supervisor answers with the host's primary interface, unless told to fail.
cat > "${tmp_dir}/bin/curl" <<'STUB'
#!/usr/bin/env bash
[ "${CURL_FAILS-}" = "true" ] && exit 7
echo '{"result":"ok","data":{"interface":"enp2s0","ipv4":{"address":["192.168.4.55/24"]}}}'
STUB

# Keep the patch definition so the test can check what would be applied.
cat > "${tmp_dir}/bin/mc-image-helper" <<STUB
#!/usr/bin/env bash
[ "\$1" = "patch" ] && cp "\$2" "${tmp_dir}/patch.json"
STUB
chmod +x "${tmp_dir}/bin/curl" "${tmp_dir}/bin/mc-image-helper"

export PLUGINS_DIR="${tmp_dir}/data/plugins"
config="${PLUGINS_DIR}/Geyser-Spigot/config.yml"
patch="${tmp_dir}/patch.json"

value() {
    jq -c --arg key "$1" '.ops[]."$put" | select(.key == $key) | .value' "${patch}"
}

# First start: no Geyser config yet, address detected from the Supervisor.
bash "${geyser_script}" > "${tmp_dir}/first.log"
grep -Fxq '  signaling:' "${config}"
test "$(jq -r .file "${patch}")" = "${config}"
test "$(value transport)" = '"both"'
test "$(value webrtc-port)" = '19133'
test "$(value advertise-addresses)" = '["192.168.4.55"]'

# An existing config is patched in place, never replaced by the seed.
echo 'config-version: 10' > "${config}"
BEDROCK_TRANSPORT=nethernet \
    BEDROCK_ADVERTISE_ADDRESSES=" 192.168.4.55 , mc.example.com:19133,," \
    bash "${geyser_script}" > "${tmp_dir}/explicit.log"
grep -Fxq 'config-version: 10' "${config}"
test "$(value transport)" = '"nethernet"'
test "$(value advertise-addresses)" = '["192.168.4.55","mc.example.com:19133"]'

# Without an address NetherNet players cannot connect, so say so loudly.
CURL_FAILS=true bash "${geyser_script}" > "${tmp_dir}/undetected.log"
test "$(value advertise-addresses)" = '[]'
grep -Fq 'WARNING: could not detect' "${tmp_dir}/undetected.log"

CURL_FAILS=true BEDROCK_TRANSPORT=raknet bash "${geyser_script}" > "${tmp_dir}/raknet.log"
if grep -Fq 'WARNING' "${tmp_dir}/raknet.log"; then
    echo "RakNet-only servers do not need an advertised address" >&2
    exit 1
fi

#!/usr/bin/env bash
set -u

log() { echo "[geyser] $*"; }

PLUGINS_DIR="${PLUGINS_DIR:-/data/plugins}"
GEYSER_DIR="${PLUGINS_DIR}/Geyser-Spigot"
GEYSER_CONFIG="${GEYSER_DIR}/config.yml"
SUPERVISOR_URL="${SUPERVISOR_URL:-http://supervisor}"
BEDROCK_TRANSPORT="${BEDROCK_TRANSPORT:-both}"

# NetherNet gets its own UDP port so RakNet can keep 19132 while both run.
NETHERNET_PORT=19133

# itzg drops to this uid:gid before running the server. Anything we create
# while still root needs to be handed over or the server cannot write to it.
SERVER_UID="${UID:-1000}"
SERVER_GID="${GID:-1000}"

# The host's primary IPv4 address, without the prefix length.
host_address() {
    curl -fsS --max-time 5 -H "Authorization: Bearer ${SUPERVISOR_TOKEN-}" \
        "${SUPERVISOR_URL}/network/interface/default/info" \
        | jq -r '.data.ipv4.address[0] // empty | split("/")[0]'
}

# NetherNet signaling tells Bedrock players which address to connect to. Left
# alone, Geyser advertises the container's own address, which nothing outside
# Home Assistant can reach, so default to the host's address instead.
advertise_addresses() {
    if [ -n "${BEDROCK_ADVERTISE_ADDRESSES-}" ]; then
        jq -cn --arg list "${BEDROCK_ADVERTISE_ADDRESSES}" \
            '$list | split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(. != ""))'
        return
    fi
    jq -cn --arg address "$(host_address 2>/dev/null)" '[$address | select(. != "")]'
}

addresses="$(advertise_addresses)"
if [ "${BEDROCK_TRANSPORT}" != "raknet" ] && [ "${addresses}" = "[]" ]; then
    log "WARNING: could not detect this host's address. Set BEDROCK_ADVERTISE_ADDRESSES or Bedrock players cannot connect over NetherNet."
fi

mkdir -p "${GEYSER_DIR}"
if [ ! -s "${GEYSER_CONFIG}" ]; then
    # Geyser writes its config on first start. Seed the parents of the keys we
    # set; Geyser fills in every other default when it loads the file.
    printf 'bedrock:\n  signaling:\n    builtin: {}\n' > "${GEYSER_CONFIG}"
fi

# mc-image-helper rewrites the whole file and drops Geyser's comments. The
# file lives in the add-on's private /data, so nobody edits it by hand.
patch="$(mktemp)"
jq -n --arg file "${GEYSER_CONFIG}" --arg transport "${BEDROCK_TRANSPORT}" \
    --argjson port "${NETHERNET_PORT}" --argjson addresses "${addresses}" '{
        file: $file,
        ops: [
            {"$put": {path: "$.bedrock", key: "transport", value: $transport}},
            {"$put": {path: "$.bedrock", key: "webrtc-port", value: $port}},
            {"$put": {path: "$.bedrock.signaling.builtin", key: "advertise-addresses", value: $addresses}}
        ]
    }' > "${patch}"
if mc-image-helper patch "${patch}"; then
    log "Bedrock transport ${BEDROCK_TRANSPORT}, NetherNet on UDP ${NETHERNET_PORT}, advertising ${addresses}"
else
    log "ERROR: failed to update ${GEYSER_CONFIG}"
fi
rm -f "${patch}"

chown -R "${SERVER_UID}:${SERVER_GID}" "${GEYSER_DIR}" 2>/dev/null || true

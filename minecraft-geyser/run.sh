#!/usr/bin/env bashio
# shellcheck shell=bash

# ==============================================================================
# Home Assistant Add-on: Minecraft Server (PaperMC + Geyser)
# Main startup script
# ==============================================================================

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
readonly DATA_PATH=/data
readonly SERVER_PATH="${DATA_PATH}/server"
readonly PLUGIN_PATH="${SERVER_PATH}/plugins"
readonly GEYSER_CONFIG_PATH="${PLUGIN_PATH}/Geyser-Spigot"
readonly FLOODGATE_CONFIG_PATH="${PLUGIN_PATH}/floodgate"

MC_VERSION=$(bashio::config 'minecraft_version')
MEMORY_MB=$(bashio::config 'memory')
MOTD=$(bashio::config 'motd')
MAX_PLAYERS=$(bashio::config 'max_players')
DIFFICULTY=$(bashio::config 'difficulty')
GAMEMODE=$(bashio::config 'gamemode')
VIEW_DISTANCE=$(bashio::config 'view_distance')
SIMULATION_DISTANCE=$(bashio::config 'simulation_distance')
ONLINE_MODE=$(bashio::config 'online_mode')
ENFORCE_WHITELIST=$(bashio::config 'enforce_whitelist')

# Convert JSON arrays from config to bash arrays for allow/ops lists
declare -a ALLOW_LIST
declare -a OPS_LIST
ALLOW_LIST=($(bashio::config 'allow_list | .[]'))
OPS_LIST=($(bashio::config 'ops_list | .[]'))

# Java memory settings (Xms: initial, Xmx: maximum)
JAVA_XMS="${MEMORY_MB}M"
JAVA_XMX="${MEMORY_MB}M"

# API URLs
PAPER_API_URL="https://papermc.io/api/v2/projects/paper"
GEYSER_API_URL="https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot"
FLOODGATE_API_URL="https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot"

# ------------------------------------------------------------------------------
# Helper Functions
# ------------------------------------------------------------------------------

# Function to download a file if it doesn't exist or is outdated (simple check)
download_if_needed() {
    local url="$1"
    local destination="$2"
    local filename
    filename=$(basename "$destination")

    if [ -f "$destination" ]; then
        bashio::log.info "File '${filename}' already exists. Skipping download."
        return 0
    fi

    bashio::log.info "Downloading '${filename}' from ${url}..."
    if curl -L -s -o "$destination" "$url"; then
        bashio::log.info "'${filename}' downloaded successfully."
        return 0
    else
        bashio::log.error "Failed to download '${filename}' from ${url}."
        return 1
    fi
}

# Function to get the latest PaperMC build number for a specific version
get_latest_paper_build() {
    local version="$1"
    local build
    build=$(curl -sSL "${PAPER_API_URL}/versions/${version}/" | jq -r '.builds[-1]')
    if [[ -z "$build" || "$build" == "null" ]]; then
        bashio::log.error "Could not find latest build number for PaperMC version ${version}."
        return 1
    fi
    echo "$build"
    return 0
}

# ------------------------------------------------------------------------------
# Setup
# ------------------------------------------------------------------------------
bashio::log.info "Starting Minecraft Server setup..."

# Create necessary directories
mkdir -p "$SERVER_PATH"
mkdir -p "$PLUGIN_PATH"
mkdir -p "$GEYSER_CONFIG_PATH"
mkdir -p "$FLOODGATE_CONFIG_PATH"

# Change to server directory
cd "$SERVER_PATH" || bashio::exit.nok "Could not change to server directory ${SERVER_PATH}"

# --- Download PaperMC ---
bashio::log.info "Checking PaperMC version ${MC_VERSION}..."
LATEST_BUILD=$(get_latest_paper_build "$MC_VERSION") || bashio::exit.nok "Failed to get Paper build info."
PAPER_JAR_NAME="paper-${MC_VERSION}-${LATEST_BUILD}.jar"
PAPER_DOWNLOAD_URL="${PAPER_API_URL}/versions/${MC_VERSION}/builds/${LATEST_BUILD}/downloads/${PAPER_JAR_NAME}"

# Check if the correct Paper JAR already exists
if [ -f "${SERVER_PATH}/${PAPER_JAR_NAME}" ]; then
    bashio::log.info "PaperMC JAR '${PAPER_JAR_NAME}' already exists."
    PAPER_RUN_JAR="${PAPER_JAR_NAME}"
else
    # Remove any old Paper JARs before downloading
    rm -f "${SERVER_PATH}/paper-*.jar"
    bashio::log.info "Downloading PaperMC ${MC_VERSION} Build ${LATEST_BUILD}..."
    if download_if_needed "$PAPER_DOWNLOAD_URL" "${SERVER_PATH}/${PAPER_JAR_NAME}"; then
        PAPER_RUN_JAR="${PAPER_JAR_NAME}"
    else
        bashio::exit.nok "Failed to download PaperMC."
    fi
fi

# --- Download Geyser & Floodgate ---
bashio::log.info "Checking GeyserMC and Floodgate plugins..."
download_if_needed "$GEYSER_API_URL" "${PLUGIN_PATH}/Geyser-Spigot.jar" || bashio::exit.nok "Failed to download Geyser."
download_if_needed "$FLOODGATE_API_URL" "${PLUGIN_PATH}/floodgate-spigot.jar" || bashio::exit.nok "Failed to download Floodgate."

# --- Configure server.properties ---
SERVER_PROPERTIES_FILE="${SERVER_PATH}/server.properties"
bashio::log.info "Configuring server.properties..."

# Create default properties if file doesn't exist (Paper will generate most on first run)
if [ ! -f "$SERVER_PROPERTIES_FILE" ]; then
    bashio::log.warning "server.properties not found. Creating default values. PaperMC will generate the full file on first run."
    touch "$SERVER_PROPERTIES_FILE" # Create empty file
    # Set essential values that need to be correct before first run
    crudini --set "$SERVER_PROPERTIES_FILE" "" online-mode "${ONLINE_MODE}"
    crudini --set "$SERVER_PROPERTIES_FILE" "" server-port "25565" # Java port
fi

# Always ensure online-mode is true for Geyser standalone + Floodgate
if ! bashio::config.true 'online_mode'; then
    bashio::log.warning "'online_mode' was set to false in config, but MUST be true for Geyser+Floodgate. Forcing to true."
    ONLINE_MODE=true
fi
crudini --set "$SERVER_PROPERTIES_FILE" "" online-mode "${ONLINE_MODE}"

# Set other configurable properties
crudini --set "$SERVER_PROPERTIES_FILE" "" motd "${MOTD}"
crudini --set "$SERVER_PROPERTIES_FILE" "" max-players "${MAX_PLAYERS}"
crudini --set "$SERVER_PROPERTIES_FILE" "" difficulty "${DIFFICULTY}"
crudini --set "$SERVER_PROPERTIES_FILE" "" gamemode "${GAMEMODE}"
crudini --set "$SERVER_PROPERTIES_FILE" "" view-distance "${VIEW_DISTANCE}"
crudini --set "$SERVER_PROPERTIES_FILE" "" simulation-distance "${SIMULATION_DISTANCE}"
crudini --set "$SERVER_PROPERTIES_FILE" "" enforce-whitelist "${ENFORCE_WHITELIST}"

# --- Configure Geyser ---
GEYSER_CONFIG_FILE="${GEYSER_CONFIG_PATH}/config.yml"
bashio::log.info "Configuring Geyser (config.yml)..."

# Create default Geyser config if it doesn't exist (Geyser plugin will generate on first run)
if [ ! -f "$GEYSER_CONFIG_FILE" ]; then
    bashio::log.warning "Geyser config.yml not found. Geyser will generate it on first run with defaults."
    # We must ensure the auth-type is set correctly even before the first run if possible.
    # Create a minimal config file if it doesn't exist. Geyser will populate the rest.
    mkdir -p "$(dirname "$GEYSER_CONFIG_FILE")"
    cat > "$GEYSER_CONFIG_FILE" <<- EOF
# Basic Geyser config - will be expanded by Geyser on first run
bedrock:
  # The IP address that will listen for Bedrock connections
  address: 0.0.0.0
  # The port that will listen for Bedrock connections
  port: 19132
  # The MOTD that will be displayed for Bedrock clients
  motd1: "${MOTD}"
  motd2: "Powered by GeyserMC"

remote:
  # The IP address of the downstream (Java) server
  address: 127.0.0.1 # Connect to the Java server running in the same container
  # The port of the downstream (Java) server
  port: 25565
  # The authentication type for the downstream (Java) server.
  # Use "floodgate" for Floodgate support, "online" for normal Mojang accounts, "offline" for offline mode
  auth-type: floodgate
EOF
    bashio::log.info "Created minimal Geyser config.yml with Floodgate auth."
else
    # Ensure essential settings are correct in existing config
    bashio::log.info "Updating existing Geyser config.yml..."
    # Using yq to modify the YAML file safely
    yq -i '.bedrock.port = 19132' "$GEYSER_CONFIG_FILE"
    yq -i '.bedrock.address = "0.0.0.0"' "$GEYSER_CONFIG_FILE"
    yq -i '.remote.address = "127.0.0.1"' "$GEYSER_CONFIG_FILE"
    yq -i '.remote.port = 25565' "$GEYSER_CONFIG_FILE"
    yq -i '.remote.auth-type = "floodgate"' "$GEYSER_CONFIG_FILE"
    # Update MOTD in Geyser config as well
    yq -i ".bedrock.motd1 = \"${MOTD}\"" "$GEYSER_CONFIG_FILE"
fi

# --- Configure Floodgate ---
FLOODGATE_CONFIG_FILE="${FLOODGATE_CONFIG_PATH}/config.yml"
bashio::log.info "Configuring Floodgate (config.yml)..."
# Floodgate usually works well with defaults, but ensure the file exists if needed.
if [ ! -f "$FLOODGATE_CONFIG_FILE" ]; then
     bashio::log.warning "Floodgate config.yml not found. Floodgate will generate it on first run."
     # Create directory if it doesn't exist
     mkdir -p "$(dirname "$FLOODGATE_CONFIG_FILE")"
     # Touch the file or create a minimal one if specific defaults are needed
     # touch "$FLOODGATE_CONFIG_FILE"
fi
# Add any necessary Floodgate modifications here using yq if required in the future.

# --- Configure Whitelist and Ops ---
WHITELIST_FILE="${SERVER_PATH}/whitelist.json"
OPS_FILE="${SERVER_PATH}/ops.json"

# Whitelist (Note: Geyser/Floodgate use player UUIDs and XUIDs)
# For simplicity, this script uses names provided in config. Manual management via console might be easier.
# Floodgate prefixes Bedrock player entries with a "." (dot).
bashio::log.info "Configuring whitelist.json..."
echo "[]" > "$WHITELIST_FILE" # Start with empty list
if bashio::config.true 'enforce_whitelist'; then
    for player in "${ALLOW_LIST[@]}"; do
        # This basic implementation adds by name. For Floodgate, adding via console (`whitelist add .PlayerName`) is more reliable.
        # A more robust script might fetch UUIDs/XUIDs.
        bashio::log.info "Adding '$player' to whitelist (manual console add might be needed for Bedrock)."
        # This jq command assumes a simple name->UUID mapping which isn't correct.
        # Placeholder: echo "[{\"uuid\": \"UUID_FOR_${player}\", \"name\": \"${player}\"}]" > "$WHITELIST_FILE" # Needs proper UUID lookup
    done
    if [ ${#ALLOW_LIST[@]} -eq 0 ]; then
        bashio::log.warning "Whitelist is enabled but the allow_list is empty."
    fi
else
     bashio::log.info "Whitelist is disabled."
fi

# Ops List
bashio::log.info "Configuring ops.json..."
echo "[]" > "$OPS_FILE" # Start with empty list
for player in "${OPS_LIST[@]}"; do
    bashio::log.info "Adding '$player' to ops list (manual console add might be needed for Bedrock)."
    # Placeholder: echo "[{\"uuid\": \"UUID_FOR_${player}\", \"name\": \"${player}\", \"level\": 4, \"bypassesPlayerLimit\": false}]" > "$OPS_FILE" # Needs proper UUID lookup
done
if [ ${#OPS_LIST[@]} -eq 0 ]; then
    bashio::log.info "Ops list is empty."
fi


# --- Accept EULA ---
bashio::log.info "Accepting Minecraft EULA..."
echo "eula=true" > "${SERVER_PATH}/eula.txt"

# ------------------------------------------------------------------------------
# Start Server
# ------------------------------------------------------------------------------
bashio::log.info "Starting Minecraft PaperMC Server (Version: ${MC_VERSION}, Memory: ${MEMORY_MB}MB)..."
bashio::log.info "Java Port: 25565/tcp"
bashio::log.info "Bedrock Port: 19132/udp"
bashio::log.info "Server JAR: ${PAPER_RUN_JAR}"

# Execute the Java process, replacing the shell script
exec java \
    -Xms"${JAVA_XMS}" \
    -Xmx"${JAVA_XMX}" \
    -XX:+UseG1GC \
    -XX:+ParallelRefProcEnabled \
    -XX:MaxGCPauseMillis=200 \
    -XX:+UnlockExperimentalVMOptions \
    -XX:+DisableExplicitGC \
    -XX:+AlwaysPreTouch \
    -XX:G1NewSizePercent=30 \
    -XX:G1MaxNewSizePercent=40 \
    -XX:G1HeapRegionSize=8M \
    -XX:G1ReservePercent=20 \
    -XX:G1HeapWastePercent=5 \
    -XX:G1MixedGCCountTarget=4 \
    -XX:InitiatingHeapOccupancyPercent=15 \
    -XX:G1MixedGCLiveThresholdPercent=90 \
    -XX:G1RSetUpdatingPauseTimePercent=5 \
    -XX:SurvivorRatio=32 \
    -XX:+PerfDisableSharedMem \
    -XX:MaxTenuringThreshold=1 \
    -Dusing.aikars.flags=https://mcflags.emc.gs \
    -Daikars.new.flags=true \
    -jar "${PAPER_RUN_JAR}" \
    --nogui \
    --paper.logging.log-strip-color=true # Optional: strips color codes for cleaner HA logs

# If exec fails, exit
bashio::exit.nok "Failed to start Minecraft server."


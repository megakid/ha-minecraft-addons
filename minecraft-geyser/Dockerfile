# minecraft-geyser/Dockerfile
# Builds the Docker image for the Home Assistant Add-on.

# Use an argument to specify the base image, allowing builds for different architectures.
ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base-debian:bullseye
FROM ${BUILD_FROM}

# Set shell for RUN commands
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install necessary dependencies:
# - openjdk-17-jre-headless: Java runtime for Minecraft server
# - curl: For downloading files
# - jq: For parsing JSON (used in run.sh to get download URLs)
# - bashio: Home Assistant helper library (already included in base image, but good practice to ensure)
# - procps: Provides 'ps' command (useful for debugging)
# - crudini: Utility to manipulate ini files (server.properties)
# - yq: Utility to manipulate YAML files (Geyser/Floodgate configs) - Install via pip
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        openjdk-17-jre-headless \
        curl \
        jq \
        procps \
        crudini \
    # Install yq (YAML processor) via pip
    && apt-get install -y --no-install-recommends python3 python3-pip \
    && pip3 install --no-cache-dir yq \
    # Clean up
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create application directory
WORKDIR /app

# Copy the run script into the container
# S6 overlay will execute this script
COPY run.sh /
RUN chmod a+x /run.sh

# Define the entry point for the container using S6 overlay
CMD [ "/run.sh" ]

# Labeling (optional but good practice)
LABEL io.hass.version="VERSION_TAG" \
      io.hass.type="addon" \
      io.hass.arch="amd64|aarch64|armv7" \
      org.opencontainers.image.title="Minecraft Server (PaperMC + Geyser)" \
      org.opencontainers.image.description="Runs a Minecraft PaperMC server with Geyser and Floodgate for Java/Bedrock cross-play." \
      org.opencontainers.image.source="https://github.com/YOUR_GITHUB_USERNAME/ha-minecraft-addons" \
      org.opencontainers.image.authors="Your Name <your.email@example.com>" \
      org.opencontainers.image.licenses="MIT" # Adjust license if needed

# Home Assistant Add-on: Minecraft Server (PaperMC + Geyser)

This add-on runs a [PaperMC](https://papermc.io/) Minecraft server, which is a high-performance fork of the standard Spigot server. It includes [GeyserMC](https://geysermc.org/) and [Floodgate](https://github.com/GeyserMC/Floodgate), allowing both Minecraft Java Edition and Minecraft Bedrock Edition clients (like Windows 10, mobile, consoles) to connect and play together. Bedrock clients do **not** need a paid Java Edition account to join.

## Installation

1.  **Add the Repository:**
    * Go to your Home Assistant instance.
    * Navigate to **Settings > Add-ons > Add-on Store**.
    * Click the 3 dots in the top right corner and select **Repositories**.
    * Enter the URL of the GitHub repository containing these add-on files (e.g., `https://github.com/YOUR_GITHUB_USERNAME/ha-minecraft-addons`) and click **Add**.
    * Close the repository management dialog.
2.  **Install the Add-on:**
    * Refresh your Add-on Store page (you might need to wait a minute).
    * Find the "Minecraft Server (PaperMC + Geyser)" add-on in the store (it might be under the repository name you added).
    * Click on the add-on and then click **Install**. Wait for the installation to complete.

## Configuration

Before starting the add-on, configure the following options under the **Configuration** tab:

* **`minecraft_version`**: The Minecraft version you want to run (e.g., "1.20.6"). Ensure PaperMC and Geyser support this version.
* **`memory`**: How much RAM (in MB) to allocate to the server (e.g., `2048` for 2GB). Allocate generously based on your Home Assistant host's resources and expected player count.
* **`motd`**: The message displayed in the server list.
* **`max_players`**: Maximum number of players allowed online simultaneously.
* **`difficulty`**: Game difficulty (`easy`, `normal`, `hard`, `peaceful`).
* **`gamemode`**: Default game mode (`survival`, `creative`, `adventure`, `spectator`).
* **`view_distance`**: How many chunks the server sends to clients.
* **`simulation_distance`**: How many chunks the server actively ticks.
* **`enforce_whitelist`**: Set to `true` to only allow players listed in `allow_list`.
* **`allow_list`**: A list of player usernames (Java) or Gamertags (Bedrock, prefixed with `.`) allowed if whitelist is enabled. *Note: Managing whitelists/ops with Bedrock players might require using the server console (`whitelist add .PlayerName`, `op .PlayerName`).*
* **`ops_list`**: A list of player usernames (Java) or Gamertags (Bedrock, prefixed with `.`) who should have operator privileges.

**Important:** `online_mode` is forced to `true` as it's required for Geyser/Floodgate to function correctly in this setup.

Click **Save** after configuring.

## Starting the Add-on

Go to the **Info** tab and click **Start**.

The first time you start the add-on, it will download PaperMC, Geyser, and Floodgate, which may take a few minutes. Check the **Log** tab for progress and any errors.

## Connecting to the Server

* **Java Edition:** Connect using your Home Assistant instance's IP address (or hostname) and the default port `25565`.
* **Bedrock Edition:** Connect using your Home Assistant instance's IP address (or hostname) and the default port `19132`.

## Data Persistence

Server data (world, plugins, configs) is stored in `/data`, which is mapped to `/share/minecraft_geyser` (or similar) on your Home Assistant host, ensuring persistence across add-on restarts and updates. You can access these files via Samba, SSH, or the File Editor add-on.

## Notes

* This add-on requires sufficient RAM and CPU resources on your Home Assistant host.
* Ensure ports `25565` (TCP) and `19132` (UDP) are open/forwarded on your router if you want players outside your local network to connect.
* Managing ops and whitelist for Bedrock players often requires using the server console. Access the console via the add-on's log interface or by attaching to the Docker container. Use the format `.PlayerName` (e.g., `op .MyBedrockGamerTag`).

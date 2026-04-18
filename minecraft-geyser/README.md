# HAMC Server (Java + Bedrock via Geyser)

This add-on hosts a Minecraft server inside Home Assistant. It runs Paper (Java)
with [Geyser]+[Floodgate] so Bedrock clients can join too. Built on top of
[itzg/minecraft-server][itzg].

## Connecting

- **Java Edition:** `<your_ip>:25565` — forward `25565/tcp` on your router for outside-LAN play.
- **Bedrock Edition:** `<your_ip>` on the default port — forward `19132/udp`.

## Bundled features

### BlueMap (3D web map) — via HA Ingress

`BLUEMAP_ENABLED` (default `true`) installs the [BlueMap] Paper plugin. The
plugin's built-in webserver is exposed through Home Assistant Ingress: open the
addon's sidebar panel ("Minecraft", cube icon) to view your world live in the
browser. No port forwarding required — it's served entirely through HA.

Pin a specific BlueMap release with `BLUEMAP_VERSION` (default `5.20`).

### DriveBackupV2 (automatic backups) — to `/media`

`BACKUP_ENABLED` (default `true`) installs the [DriveBackupV2] Paper plugin and,
on first boot, seeds a config that writes ZIP backups of all worlds to
`/media/minecraft-backups/`. Browse and download them via Home Assistant's
Media browser.

- `BACKUP_DELAY_MINUTES` — minutes between backups (default `1440` = daily).
- `BACKUP_KEEP_COUNT` — how many backups to retain (default `7`).

After first boot you can edit `/data/plugins/DriveBackupV2/config.yml` (e.g. via
the SSH or Samba addon) to set up Google Drive / OneDrive / Dropbox destinations
or refine the schedule. The seeded config is written **once** and not
overwritten on subsequent starts.

### RCON (remote admin)

Set `ENABLE_RCON: true` and `RCON_PASSWORD: <something>`. RCON listens on
`25575/tcp` (forwarded by the addon). Use any RCON client to send server
commands without needing to be in-game.

## All options

Most options pass straight through to itzg/minecraft-server — see the [full
list][itzg-env] for everything available. Common ones are exposed in the addon
configuration screen.

[Geyser]: https://geysermc.org
[Floodgate]: https://github.com/GeyserMC/Floodgate
[itzg]: https://github.com/itzg/docker-minecraft-server
[itzg-env]: https://docker-minecraft-server.readthedocs.io/en/latest/variables/
[BlueMap]: https://bluemap.bluecolored.de/
[DriveBackupV2]: https://github.com/MaxMaeder/DriveBackupV2

## Acknowledgements

- Add-on template by [alexbelgium](https://github.com/alexbelgium/hassio-addons).
- Minecraft server image by [itzg](https://github.com/itzg/docker-minecraft-server).

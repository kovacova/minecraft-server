# Part 3: More than one world

**The goal:** keep several worlds on the server (yours, your sister's, a creative
one) and pick which one is live.

**How it works:** a Minecraft server plays **one world at a time**. Each world is
just a folder in `/srv/minecraft`. One line in `server.properties` says which folder
is live:

```
level-name=world
```

Change that line, restart, and you're in a different world. That's the whole trick.

**Time:** 15 minutes for the first world, 1 minute to switch after that. **Cost:** nothing extra.

---

## ⚠️ First: check the world's version

A server can open worlds from **its own version or older**, never newer. Opening a
world in an older version can break it, so Minecraft refuses.

- The server runs whatever `minecraft_version` says in `terraform.tfvars`.
- To see a world's version: in Minecraft's world list, it shows under the world's name.

**Hidden Layers was last opened in `26.4 Snapshot 1`, so a 26.3 server can't load it.**
Two options:

1. **Wait for 26.4** (Mojang usually releases a few weeks after the snapshots),
   then set `minecraft_version = "26.4"` and `tofu apply`. **Safest.**
2. Run the snapshot now: `minecraft_version = "26.4-snapshot-2"`. But then *every*
   world on the server gets upgraded to a snapshot, and snapshots can have bugs
   that damage worlds. Only do this after a backup (`sudo mc-backup.sh`).

---

## Step 1: Zip the world

**Close the world in Minecraft first**, then:

**Windows** (PowerShell):
```powershell
tar -a -c -f "$HOME\Desktop\myworld.zip" -C "$env:APPDATA\.minecraft\saves" "World Name"
```

**Mac** (Terminal):
```bash
cd ~/Library/Application\ Support/minecraft/saves
zip -r ~/Desktop/hidden-layers.zip "Hidden Layers"
```

✅ **Check:** there's a `.zip` on your Desktop.

## Step 2: Upload it

**From the command line** (in the `terraform` folder):
```powershell
aws s3 cp "$HOME\Desktop\myworld.zip" "s3://$(tofu output -raw backup_bucket)/import/" --profile minecraft
```

**Or by drag and drop** (easier for someone without the command line set up):
AWS console → **S3** → the `minecraft-backups-…` bucket → open (or create) the
`import/` folder → **Upload** → drop the zip in.

✅ **Check:** the zip shows up in `import/` in the S3 console.

## Step 3: Put it on the server

Make sure the server is on (`/start` in Discord), then open the server shell:

```powershell
Invoke-Expression (tofu output -raw shell)
```

In the server shell:

```bash
sudo import-world.sh myworld.zip
```

This stops the server, unpacks the world next to the others, makes it the live
one, and starts again. **Everyone online gets kicked for about 30 seconds.** Your
old world isn't touched. It stays in its own folder.

✅ **Check:** it ends with `now serving world 'World Name'`.

## Step 4: See all your worlds

```bash
ls /srv/minecraft
grep level-name /srv/minecraft/server.properties
```

The first shows every folder. The worlds are the ones you recognise (`world`,
`Hidden Layers`, …), and the rest is server stuff. The second shows which world is live.

## Step 5: Switch worlds

Three commands: stop, change the line, start. Swap `world` for the folder name you want:

```bash
sudo systemctl stop minecraft
sudo sed -i 's/^level-name=.*/level-name=world/' /srv/minecraft/server.properties
sudo systemctl start minecraft
```

For a name with spaces, it's the same: `level-name=Hidden Layers`.

✅ **Check:** `sudo mc list` answers after ~30 seconds. Rejoin, and you're in the other world.

---

## Good to know

- **The whitelist and ops are shared** by every world. Inventories are per world.
- **Backups:** each stop backs up the world that was live. A world you imported but
  never played is still safe: its zip stays in `import/`.
- **A world you don't want anymore:** stop the server, then `sudo rm -r "/srv/minecraft/Folder Name"`.
  There's no undo, so be sure it's not the live one.

## Ideas for later

- **Write your own `mc-world` command** that does Step 5 in one go: `sudo mc-world use world`.
  Look at `server/mc-backup.sh` for how the scripts find the live world. Then
  add it to `server/cloud-init.sh.tftpl` so every new server has it.
- **A `/world` command in the Discord bot.** The bot would need permission to run
  commands on the server. Look up `ssm:SendCommand`.
- **Both worlds live at once:** the Multiverse plugin on a Paper server lets players
  hop between worlds with `/mv tp`. Paper plugins are written in Java. 😉

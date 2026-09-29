#!/bin/bash
# Replace the server's world with one uploaded to s3://<bucket>/import/<name>.zip
# Run on the server: sudo bash import-world.sh MyWorld.zip
# The current world is backed up first (the stop does that) and kept as <name>.before-import.
set -euo pipefail
source /etc/minecraft.env
zip="${1:?usage: import-world.sh <file>.zip}"
cd /srv/minecraft

systemctl stop minecraft.service   # saves and backs up the current world

tmp="$(mktemp -d)"
aws s3 cp --only-show-errors "s3://$BACKUP_BUCKET/import/$zip" "$tmp/world.zip"
unzip -q "$tmp/world.zip" -d "$tmp/out"

# The zip holds the world folder itself; level.dat marks its top.
top="$(dirname "$(find "$tmp/out" -maxdepth 3 -name level.dat | head -1)")"
[ -f "$top/level.dat" ] || { echo "no level.dat in $zip - is it a Minecraft world?"; exit 1; }
name="$(basename "$top")"

[ -d "$name" ] && mv "$name" "$name.before-import.$(date +%s)"
mv "$top" "./$name"
sed -i "s/^level-name=.*/level-name=$name/" server.properties
grep -q '^level-name=' server.properties || echo "level-name=$name" >> server.properties
chown -R minecraft:minecraft "$name" server.properties
rm -rf "$tmp"

systemctl start minecraft.service
echo "now serving world '$name'"

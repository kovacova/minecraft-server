#!/bin/bash
# Archive the world and its settings to S3. Runs after every server stop
# (ExecStopPost), and by hand: sudo /usr/local/bin/mc-backup.sh
set -euo pipefail
source /etc/minecraft.env
cd /srv/minecraft

level="$(sed -n 's/^level-name=//p' server.properties)"
level="${level:-world}"
[ -d "$level" ] || { echo "no world folder '$level' yet, nothing to back up"; exit 0; }

stamp="$(date -u +%Y-%m-%dT%H%MZ)"
archive="/tmp/minecraft-$stamp.tar.gz"
tar -czf "$archive" "$level" server.properties whitelist.json ops.json banned-players.json 2>/dev/null \
  || tar -czf "$archive" "$level"
aws s3 cp --only-show-errors "$archive" "s3://$BACKUP_BUCKET/backups/$stamp.tar.gz"
rm -f "$archive"
echo "backed up $level to s3://$BACKUP_BUCKET/backups/$stamp.tar.gz"

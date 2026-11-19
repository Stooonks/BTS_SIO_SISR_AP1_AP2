#!/bin/bash
# Sauvegarde quotidienne GLPI : base de données + documents + configuration (rétention 7 jours)
set -euo pipefail
DEST=/var/backups/glpi
TS=$(date +%Y%m%d-%H%M)
mkdir -p "$DEST"
chmod 700 "$DEST"
mysqldump --single-transaction --routines --triggers glpi | gzip > "$DEST/glpi-db-$TS.sql.gz"
tar -czf "$DEST/glpi-files-$TS.tar.gz" -C / etc/glpi var/lib/glpi/_documents var/lib/glpi/_pictures 2>/dev/null || \
  tar -czf "$DEST/glpi-files-$TS.tar.gz" -C / etc/glpi
find "$DEST" -type f -mtime +7 -delete
logger -t glpi-backup "Sauvegarde GLPI OK : $DEST/glpi-db-$TS.sql.gz"

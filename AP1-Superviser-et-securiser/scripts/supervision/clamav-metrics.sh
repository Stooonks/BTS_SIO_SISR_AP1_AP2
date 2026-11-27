#!/bin/bash
# Métriques ClamAV pour Prometheus (collecteur textfile de node_exporter), lancé par cron
set -u
DIR=/var/lib/prometheus/node-exporter
mkdir -p "$DIR"
TMP=$(mktemp "$DIR/.clamav.XXXXXX")

if V=$(clamdscan --version 2>/dev/null); then UP=1; else UP=0; V=""; fi
DBVER=$(echo "$V" | awk -F/ '{print $2}')

SIGS=0
for f in /var/lib/clamav/{main,daily,bytecode}.c[vl]d; do
  [ -f "$f" ] || continue
  n=$(sigtool --info "$f" 2>/dev/null | awk '/^Signatures:/{print $2}')
  SIGS=$((SIGS + ${n:-0}))
done
DBTIME=$(stat -c %Y /var/lib/clamav/daily.c[vl]d 2>/dev/null | sort -n | tail -1)

# Protection en temps réel (clamonacc) et services
ONACC=0; pgrep -x clamonacc >/dev/null && ONACC=1
FRESH=0; systemctl is-active --quiet clamav-freshclam && FRESH=1

# Dernière analyse hebdomadaire (dernier bloc SCAN SUMMARY)
LOG=/var/log/clamav/scan-hebdo.log
S_FILES=0; S_INF=0; S_DUR=0; S_END=0
if [ -f "$LOG" ]; then
  BLOC=$(tac "$LOG" | sed '/SCAN SUMMARY/q' | tac)
  S_FILES=$(echo "$BLOC" | awk -F': ' '/^Scanned files/{print $2}')
  S_INF=$(echo "$BLOC"   | awk -F': ' '/^Infected files/{print $2}')
  S_DUR=$(echo "$BLOC"   | awk '/^Time:/{print $2}')
  END=$(echo "$BLOC"     | awk -F'Date: *' '/^End Date/{print $2}' | sed 's/:/-/; s/:/-/')
  [ -n "$END" ] && S_END=$(date -d "$END" +%s 2>/dev/null || echo 0)
fi

{
  echo "# HELP clamav_up 1 si le démon clamd répond"
  echo "# TYPE clamav_up gauge"
  echo "clamav_up $UP"
  echo "# TYPE clamav_db_version gauge"
  echo "clamav_db_version ${DBVER:-0}"
  echo "# TYPE clamav_signatures_total gauge"
  echo "clamav_signatures_total $SIGS"
  echo "# TYPE clamav_db_updated_timestamp_seconds gauge"
  echo "clamav_db_updated_timestamp_seconds ${DBTIME:-0}"
  echo "# HELP clamav_onaccess_up 1 si la protection en temps réel (clamonacc) tourne"
  echo "# TYPE clamav_onaccess_up gauge"
  echo "clamav_onaccess_up $ONACC"
  echo "# TYPE clamav_freshclam_up gauge"
  echo "clamav_freshclam_up $FRESH"
  echo "# HELP clamav_scan_last_files Fichiers analysés lors de la dernière analyse hebdomadaire"
  echo "# TYPE clamav_scan_last_files gauge"
  echo "clamav_scan_last_files ${S_FILES:-0}"
  echo "# TYPE clamav_scan_last_infected gauge"
  echo "clamav_scan_last_infected ${S_INF:-0}"
  echo "# TYPE clamav_scan_last_duration_seconds gauge"
  echo "clamav_scan_last_duration_seconds ${S_DUR:-0}"
  echo "# TYPE clamav_scan_last_end_timestamp_seconds gauge"
  echo "clamav_scan_last_end_timestamp_seconds ${S_END:-0}"
} > "$TMP"
chmod 644 "$TMP"
mv "$TMP" "$DIR/clamav.prom"

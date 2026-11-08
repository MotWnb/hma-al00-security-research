#!/bin/bash
ls -lt --time-style=+%H:%M:%S /opt/lab/logs/*.log | head -5
echo
for f in $(ls -t /opt/lab/logs/*.log | head -3); do
  echo "== $f  ($(stat -c%s "$f") bytes)"
  grep -nE 'INIT_OK|Run /init|PARAMS|^.*TRY |WON|HIT|TIMER_FIRED|Kernel panic|KASAN' "$f" | head -10
  echo
done

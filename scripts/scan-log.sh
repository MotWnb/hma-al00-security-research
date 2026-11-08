#!/bin/bash
# usage: scan-log.sh <log>  -- prints evidence markers for CVE-2025-38352 stage A
L="$1"
if [ ! -f "$L" ]; then echo "no such log: $L"; exit 2; fi
echo "== file: $L ($(wc -l < "$L") lines) =="
echo "-- kernel version --"; grep -m2 -E "Linux version 4\.14" "$L"
echo "-- kasan enabled --"; grep -m3 -iE "kasan|KernelAddressSanitizer" "$L"
echo "-- WARN at posix_cpu_timer_del --"
grep -n -B2 -A12 -E "posix_cpu_timer_del|it\.cpu\.entry|WARNING: CPU" "$L" | head -60
echo "-- kasan UAF --"
grep -n -A20 -iE "use-after-free|BUG: KASAN" "$L" | head -80
echo "-- trigger markers --"
grep -nE "^(TRY|TIMER_FIRED|DELETED|WON|HIT|INIT_OK)" "$L" | tail -20
echo "-- panic/oops --"
grep -nE "Kernel panic|Unable to handle|Oops|BUG:" "$L" | head -10

#!/bin/bash
# Stage A boot with SMC PSCI conduit (vendor kernel hardcodes SMC when CONFIG_ARCH_HISI)
set -u
IMG=/opt/lab/build/arch/arm64/boot/Image
INITRD=/opt/lab/trig/trigger-initramfs.cpio.gz
LOG=${1:-/opt/lab/logs/boot-smc.log}
SECS=${2:-120}
shift 2 2>/dev/null || true
: > "$LOG"
timeout "$SECS" qemu-system-aarch64 \
  -M virt,secure=on,psci-conduit=smc -cpu cortex-a72 -smp 4 -m 3072 \
  -kernel "$IMG" -initrd "$INITRD" \
  -append "console=ttyAMA0 earlycon=pl011,0x9000000 keep_bootcon rdinit=/init panic=-1 loglevel=7 ${EXTRA_APPEND:-}" \
  -serial "file:$LOG" -display none -no-reboot
echo "qemu exit=$?" >> "$LOG"

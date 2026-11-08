#!/bin/bash
# Independent boot probe: boots Image with trigger initramfs, logs to file, no pipes.
set -u
IMG=${1:-/opt/lab/build/arch/arm64/boot/Image}
INITRD=${2:-/opt/lab/trig/trigger-initramfs.cpio.gz}
LOG=${3:-/opt/lab/logs/boot-probe.log}
SECS=${4:-120}
: > "$LOG"
timeout "$SECS" qemu-system-aarch64 \
  -M virt -cpu cortex-a72 -smp 4 -m 3072 \
  -kernel "$IMG" -initrd "$INITRD" \
  -append "console=ttyAMA0 earlycon=pl011,0x9000000 keep_bootcon rdinit=/init panic=-1 loglevel=7" \
  -serial "file:$LOG" -display none -no-reboot
echo "qemu exit=$?" >> "$LOG"

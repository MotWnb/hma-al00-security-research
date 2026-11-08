#!/bin/bash
# run-qemu.sh — boot a kernel Image + initramfs under QEMU ARM64 and capture the serial log
#
# usage: ./run-qemu.sh <Image> <initramfs.cpio.gz> [logname] [timeout_s] [extra-append]
#   logname   defaults to qemu-<timestamp>.log, written under $LOGDIR
#   timeout_s defaults to 180 (0 = no timeout)
#   extra-append is appended to the kernel cmdline (e.g. "panic=1 oops=panic")
#
# env: LOGDIR (default /opt/lab/logs), QEMU (default qemu-system-aarch64),
#      SMP (default 4), MEM_MB (default 3072), CPU (default cortex-a72)
set -u

IMG=${1:?usage: run-qemu.sh <Image> <initramfs> [logname] [timeout] [extra-append]}
INITRD=${2:?usage: run-qemu.sh <Image> <initramfs> [logname] [timeout] [extra-append]}
NAME=${3:-qemu-$(date +%Y%m%d-%H%M%S).log}
TMO=${4:-180}
EXTRA=${5:-}

LOGDIR=${LOGDIR:-/opt/lab/logs}
QEMU=${QEMU:-qemu-system-aarch64}
SMP=${SMP:-4}
MEM_MB=${MEM_MB:-3072}
CPU=${CPU:-cortex-a72}

mkdir -p "$LOGDIR"
LOG="$LOGDIR/$NAME"

APPEND="console=ttyAMA0 rdinit=/init panic=-1 loglevel=7"
[ -n "$EXTRA" ] && APPEND="$APPEND $EXTRA"

echo "== run $(date -Is) image=$IMG initrd=$INITRD log=$LOG ==" | tee "$LOG"

# -no-reboot + panic=-1 make the guest terminate instead of hanging on a panic.
# timeout is applied only when TMO > 0.
if [ "$TMO" -gt 0 ] 2>/dev/null; then
    timeout "$TMO" "$QEMU" -M virt -cpu "$CPU" -smp "$SMP" -m "$MEM_MB" \
        -kernel "$IMG" -initrd "$INITRD" -append "$APPEND" \
        -nographic -no-reboot >>"$LOG" 2>&1
    RC=$?
else
    "$QEMU" -M virt -cpu "$CPU" -smp "$SMP" -m "$MEM_MB" \
        -kernel "$IMG" -initrd "$INITRD" -append "$APPEND" \
        -nographic -no-reboot >>"$LOG" 2>&1
    RC=$?
fi

echo "== exit=$RC $(date -Is) ==" | tee -a "$LOG"
echo "log: $LOG"
exit "$RC"

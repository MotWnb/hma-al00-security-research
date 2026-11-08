#!/bin/bash
cfg=/opt/lab/build/.config
for s in CONFIG_VIRTIO_MMIO CONFIG_VIRTIO_BLK CONFIG_POSIX_TIMERS CONFIG_HIGH_RES_TIMERS \
         CONFIG_FUTEX_PI CONFIG_PREEMPT CONFIG_KASAN CONFIG_ARM_GIC_V3 CONFIG_ARM_PSCI_FW \
         CONFIG_SERIAL_AMBA_PL011_CONSOLE CONFIG_HZ CONFIG_BLK_DEV_INITRD CONFIG_DEVTMPFS \
         CONFIG_SIGNALFD CONFIG_TIMERFD CONFIG_MULTIUSER CONFIG_SMP; do
  v=$(grep -E "^${s}=" "$cfg" || true)
  [ -z "$v" ] && v="MISSING"
  printf '%s\n' "$v"
done
echo '-- disabled subsystems --'
grep -E '^# CONFIG_(PCI|FB|DRM|SOUND|MMC|I2C|REGULATOR|MTD|SPI) is not set' "$cfg" || true
echo '-- vendor hw dirs still referenced --'
grep -nE 'hwpower|hisi/dpu|sim_adapt' /opt/lab/kernel/drivers/Makefile /opt/lab/kernel/drivers/video/fbdev/Makefile 2>/dev/null || true

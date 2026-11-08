# qemu/ — offline ARM64 lab

The lab boots the **vendor's own 4.14.116 kernel** on QEMU `virt`, so that kernel-side statements can be tested without touching the phone.

## 1. Requirements

| Component | Version used | Notes |
|---|---|---|
| Host | Ubuntu 24.04/26.04 (WSL2 is fine) | 16 vCPU, 7 GB RAM, ~8 GB disk |
| QEMU | 10.2.1 (`qemu-system-aarch64`) | any ≥ 7 with `virt` + PL011 should work |
| Cross GCC | `gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu` | GCC 14+ rejects constructs the 4.14 tree still uses |
| Kernel source | vendor `HMA-AL00-TL00_HarmonyOS4.0.0` | see [../SOURCE_PROVENANCE.md](../SOURCE_PROVENANCE.md) |

```bash
sudo apt-get install -y qemu-system-arm qemu-utils bc bison flex libssl-dev \
                        libelf-dev cpio make gcc build-essential perl python3 \
                        xz-utils wget curl rsync file
```

Toolchain:

```bash
wget https://developer.arm.com/-/media/Files/downloads/gnu-a/9.2-2019.12/binrel/gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu.tar.xz
sudo mkdir -p /opt/lab && sudo tar -xf gcc-arm-9.2-*.tar.xz -C /opt/lab/toolchain
export CROSS=/opt/lab/toolchain/gcc-arm-9.2-2019.12-x86_64-aarch64-none-linux-gnu/bin/aarch64-none-linux-gnu-
```

## 2. Prepare the tree

```bash
tar -xf HMA-AL00-TL00_HormonyOS4.0.0_opensource.tar.gz
export KSRC=$PWD/Code_Opensource/kernel

# The vendor tree ships only merge_kirin980_defconfig, which is device-specific.
# Start from the stable v4.14.116 arm64 defconfig instead:
wget -O $KSRC/arch/arm64/configs/qemu_defconfig \
  "https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/arch/arm64/configs/defconfig?h=v4.14.116"
```

Apply the nine patches in order (see [../patches/README.md](../patches/README.md)):

```bash
cd $KSRC
for p in ../patches/printk-h.patch ../patches/jump_label.patch ../patches/workingset.patch \
         ../patches/blk-h.patch ../patches/cpu-errata.patch ../patches/process-c.patch \
         ../patches/alarmtimer-c.patch ../patches/drivers-Makefile.patch \
         ../patches/drivers-Makefile-hwpower.patch; do patch -p1 < "$p"; done
```

## 3. Configure

```bash
mkdir -p /opt/lab/build
make -C $KSRC O=/opt/lab/build ARCH=arm64 qemu_defconfig
/opt/lab/build/scripts/config --file /opt/lab/build/.config \
  -e KASAN -e DEBUG_INFO -e KALLSYMS_ALL -e FRAME_POINTER -e PREEMPT -e HZ_1000 \
  -e POSIX_TIMERS -e HIGH_RES_TIMERS -e FUTEX -e FUTEX_PI -e BLK_DEV_INITRD -e RD_GZIP \
  -e DEVTMPFS -e DEVTMPFS_MOUNT -e SERIAL_AMBA_PL011 -e SERIAL_AMBA_PL011_CONSOLE \
  -e ARM_GIC_V3 -e ARM_PSCI_FW -e VIRTIO -e VIRTIO_MMIO -e VIRTIO_BLK \
  -d RANDOMIZE_BASE -d MODULE_SIG_FORCE -d TRANSPARENT_HUGEPAGE \
  -d SERIAL_8250 -d GPIO_PL061 -d GPIO_GENERIC -d KEYBOARD_GPIO -d KEYBOARD_GPIO_POLLED -d GPIO_KEYS
make -C $KSRC O=/opt/lab/build ARCH=arm64 olddefconfig
```

The resulting configuration is published verbatim as [../KERNEL_CONFIG/lab-config-arm64-4.14.116](../KERNEL_CONFIG/lab-config-arm64-4.14.116).

## 4. Build

```bash
make -C $KSRC O=/opt/lab/build ARCH=arm64 CROSS_COMPILE=$CROSS \
     CC=${CROSS}gcc HOSTCC=gcc HOSTCXX=g++ CCACHE= -j8 Image
# -> /opt/lab/build/arch/arm64/boot/Image  (~26 MB)
```

Note: the vendor `Makefile` hard-codes a clang prebuilt path (`CC=…/clang-r353983c/bin/clang`); the command line above overrides it rather than editing the tree.

## 5. Minimal initramfs

A static `init` that prints a marker and powers off is enough to prove the boot; the race experiments use their own initramfs (not published).

```bash
mkdir -p rootfs && cp init rootfs/init
(cd rootfs && find . | cpio -o -H newc | gzip -9) > initramfs.cpio.gz
```

## 6. Boot

```bash
qemu-system-aarch64 -M virt -cpu cortex-a72 -smp 4 -m 3072 \
  -kernel /opt/lab/build/arch/arm64/boot/Image \
  -initrd initramfs.cpio.gz \
  -append "console=ttyAMA0 rdinit=/init panic=-1 loglevel=7" \
  -nographic -no-reboot
```

Or use the wrapper: [`run-qemu.sh`](run-qemu.sh).

Expected tail of a clean boot:

```
=== INIT START ===
INIT_OK
Linux version 4.14.116 (root@<host>) (gcc version 9.2.1 ...) #8 SMP PREEMPT
=== INIT DONE, powering off ===
```

Full sanitized excerpt: [../logs/sanitized/boot-clean.excerpt.log](../logs/sanitized/boot-clean.excerpt.log).

## 7. Known QEMU-only pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| `undefined instruction` at `has_ssbd_mitigation` | vendor hard-codes `smc #0` for the PSCI conduit; no EL3 under QEMU | `cpu-errata.patch` |
| `BUG_ON` in `__hwspin_trylock` from `pl061_direction_input` | vendor GPIO spinlock check trips on QEMU's `gpio-keys` node | disable `GPIO_PL061`/`GPIO_KEYS` |
| KASAN `slab-out-of-bounds` in `platform_uevent` at boot | 4.14 `serdev`/`8250` issue unrelated to this study | disable `SERIAL_8250`, use PL011 |
| `vdso-offsets.h` empty / build restart loop | parallel race when `vdso.so.dbg` is missing | `rm -f` the header and `vdso.so.dbg`, rebuild |

# KERNEL_CONFIG

Two files:

| File | What it is |
|---|---|
| `device-config-relevant.txt` | 95 decisive symbols extracted from the **device's** `/proc/config.gz` (Linux/arm64 4.14.116, built 2024-01-24). Read-only pull; no modification. |
| `lab-config-arm64-4.14.116` | The complete `.config` used to build the QEMU lab kernel — 4.14.116 vendor tree + the nine adaptations in `../patches/`. |

## Reading the device excerpt

The device config is a 6,754-line file. Only symbols that decide an attack-surface question are published. The most important ones:

```
# CONFIG_NAMESPACES is not set        -> user/pid/net/mount namespaces do not exist
CONFIG_MODULE_SIG_FORCE=y             -> unsigned modules cannot load
# CONFIG_SECURITY_SELINUX_DEVELOP is not set  -> no permissive toggle
# CONFIG_FORTIFY_SOURCE is not set     -> (hardening gap, but no direct primitive)
CONFIG_ARM64_PAN=y                    -> no kernel access to user mappings
CONFIG_RANDOMIZE_BASE=y               -> KASLR on
CONFIG_HW_FUTEX_PI=y                  -> vendor futex-PI gate compiled in
CONFIG_CFI=y  CONFIG_CFI_CLANG=y      -> forward-edge CFI on
# CONFIG_CHECKPOINT_RESTORE is not set -> no PR_SET_MM_MAP
# CONFIG_UNMAP_KERNEL_AT_EL0 is not set -> no KPTI
```

`CONFIG_POSIX_CPU_TIMERS_TASK_WORK` is **absent** — it does not exist in the 4.14 tree at all.

## Reading the lab config

The lab config starts from `arch/arm64/configs/defconfig` of the **stable v4.14.116** release (the vendor tree ships only `merge_kirin980_defconfig`), then:

* enables KASAN, debug info, `KALLSYMS_ALL`, `FRAME_POINTER`, `HZ=1000`;
* keeps `PREEMPT=y`, `POSIX_TIMERS`, `HIGH_RES_TIMERS`, `FUTEX_PI`;
* disables `RANDOMIZE_BASE` (debuggability) and subsystems not needed under QEMU;
* disables THP, which the vendor arm64 tree does not implement and which the device also has off.

The exact differences between lab and device are listed in [../experiments/results/stage-a.md](../experiments/results/stage-a.md) §3, because every lab result must be read with them in mind.

## How the device config was obtained

```bash
adb pull /proc/config.gz        # 42,779 bytes, readable by shell
python -c "import gzip;open('config','wb').write(gzip.open('config.gz','rb').read())"
# 6,754 lines
```

SHA-256 of the original `config.gz`: `EDD2A0132432004D1B36F8E5FF2F426C8E5F21E58AB6243085F59596CDD24DF3`.

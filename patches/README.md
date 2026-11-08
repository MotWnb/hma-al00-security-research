# patches/ — nine adaptations to build the vendor tree on QEMU

These patches exist because the **vendor's** 4.14.116 tree does not compile cleanly with GCC 9.2 on a generic arm64 `virt` machine, and because the vendor modified core files in ways that only work on Huawei hardware.

They are **not** vulnerability fixes, and **none of them touches `kernel/time/posix-cpu-timers.c`** — the CVE-2025-38352 code under study is compiled exactly as shipped.

All patches are `diff -u` against the vendor tree. Apply in the order below from the kernel root (`patch -p1 < ...`). Every original file is preserved with a `.orig` suffix inside the lab (not published; hashes are in the private archive).

| # | Patch | File | Why |
|---|---|---|---|
| 1 | `printk-h.patch` | `include/linux/printk.h` | Vendor adds `extern u64 local_clock(void)` behind `#ifdef CONFIG_HISI_TIME`; on arm64 `sched/clock.h` defines `static inline local_clock()`, so GCC 9.2 rejects the static-after-non-static declaration. Lab-only: provide an inert `hisi_getcurtime()` stub under `CONFIG_ARM64` when `HISI_TIME=n`. |
| 2 | `jump_label.patch` | `kernel/jump_label.c` | Vendor tree contains **two** definitions of `static_key_enable/disable` (an old wrapper pair plus the upstream `*_cpuslocked` versions). Removing the duplicate pair is behaviour-preserving: both are idempotent 0↔1 transitions under `cpus_read_lock`, and the update is serialised by `jump_label_lock`. |
| 3 | `workingset.patch` | `mm/workingset.c` | Missing `#include <linux/mm.h>` for `lruvec`/`pgdat` types under this config. |
| 4 | `blk-h.patch` | `block/blk.h` | Vendor typo: `elevator_exit()` calls `elevator_exit(q, e)` recursively; upstream calls `__elevator_exit()`. One-line fix, otherwise always-inline recursion error. |
| 5 | `cpu-errata.patch` | `arch/arm64/kernel/cpu_errata.c` | **Vendor bug.** Under `CONFIG_ARCH_HISI` four `switch (psci_ops.conduit)` statements are replaced by `switch (PSCI_CONDUIT_SMC)`, i.e. the kernel always emits `smc #0`. QEMU `virt` has no EL3 → `Internal error: undefined instruction` in `has_ssbd_mitigation`. Restores the upstream conduit switch in all four places. |
| 6 | `process-c.patch` | `arch/arm64/kernel/process.c` | `hisi_pm_system_reset_comm()` is called unconditionally but only provided when `CONFIG_HISI_POWER_OFF` is on; guard the call. Under QEMU reboot goes through PSCI and never reaches the vendor hook. |
| 7 | `alarmtimer-c.patch` | `kernel/time/alarmtimer.c` | Guards vendor RTC hooks (`hisi_pmu_rtc_setalarmtime/readtime`) behind `CONFIG_RTC_DRV_HISI_PMIC_SPMI` and the `runmode_is_factory()` alarm block behind `CONFIG_HISI_CMDLINE_PARSE`. When those options are off these are vendor-only additions; the `#else` path is upstream 4.14.116 verbatim. |
| 8 | `drivers-Makefile.patch` | `drivers/Makefile` | `obj-y += hisi_sim_adapt/` is unconditional but depends on a `CONFIG_HISI_PMIC` symbol that does not exist in this tree (and no Kconfig switch guards it). Commented out; the directory only exports library functions, registers no device/initcall. |
| 9 | `drivers-Makefile-hwpower.patch` | `drivers/Makefile` | `obj-y += hwpower/` is unconditional but `power_i2c.c` calls `i2c_transfer()` while I2C is disabled for QEMU. Commented out. |

## What was *not* patched

* `kernel/time/posix-cpu-timers.c` — zero changes. `strings Image | grep -c PCBDBG` = 0 for the published clean image (the diagnostic probes were rolled back).
* `kernel/futex.c`, `kernel/locking/rtmutex.c` — zero changes.
* No config-disabled hardening was turned off to "make the bug work": KASAN, CFI, PAN, PREEMPT and the timer code are as the vendor ships them.

## License

Each patch is a derivative of the vendor's GPL-2.0 kernel source and remains **GPL-2.0**; it is not relicensed. See [../LICENSES.md](../LICENSES.md).

## Verification

The clean image built from this tree boots to `INIT_OK` with no KASAN/panic/warning output — see [../logs/sanitized/boot-clean.excerpt.log](../logs/sanitized/boot-clean.excerpt.log).

# Execution log (sanitized)

High-level chronology of the investigation. Host names, device serials and local paths are removed; every experiment below ran in an isolated QEMU ARM64 guest unless marked "device".

## 2026-11-08 — device baseline

- Read-only `adb` survey: build `HMA-AL00 10.1.0.163(C00E160R1P8)`, HarmonyOS 4.0.0 / EMUI 14.0.0, Android 10 (API 29), kernel 4.14.116 built 2024-01-24, Huawei patch level 2024-02-01.
- Verified lock state: `flash.locked=1`, `verifiedbootstate=green`, `veritymode=enforcing`, `vbmeta.device_state=locked`.
- Verified confinement: no `su`, `adb root` refused, SELinux enforcing, `CapEff=0`, no user namespaces, `/proc/kallsyms` and `/proc/vmallocinfo` denied to `shell`.
- Pulled `/proc/config.gz`; extracted 6,754-line config and recorded the hardening set (module signature enforcement, PAN, KASLR, hardened usercopy, SELinux without `DEVELOP`).

## 2026-11-08 — kernel source and driver audit

- Retrieved the vendor's official open-source package (`HMA-AL00-TL00_HarmonyOS4.0.0`, 592,682,548 B, SHA-256 `F2FD7D23…8036`); its `README_Version.txt` states the package matches the 2024-01-24 phone software, i.e. the exact kernel on the device.
- Audited Mali `bifrost-r18p0-01rel0`: the fix patterns for CVE-2021-28664 / CVE-2022-22706 / CVE-2023-4211 are present (`write` flag derivation, `kbase_vmap_prot`, single-page tracking VMA).
- Audited Huawei DFX drivers (`hw_logger`, `zrhung`, `memcheck`): the 2022 root causes are still in the 2024-01-24 source (`hcfgk_set_cfg()`'s second check outside the update, `%pS` on raw kernel addresses), but reachability is governed by SELinux `allowxperm`, not by DAC.

## 2026-11-08 — device probe of the DFX surface

- A small static aarch64 probe (built with the local NDK) opened the three `/dev/hwlog_*` nodes and issued representative ioctls.
- Result: `open()` succeeds, but `SET_HCFG` / `SET_FEATURE` / `READ_HEVENT` return `EACCES`; only `GET_STACK` reaches the driver (`EFAULT`, bad pointer) and the generic `GET_LOG_BUF_SIZE` works. Only the `hwlog_exception` node dispatches to `zrhung`/`memcheck`; `hwlog_dubai` and `hwlog_jank` return `EINVAL` for those commands.
- Conclusion: the 2022 TASZK primitive ("reach every hwlog ioctl through dubai") has been structurally removed on this build.

## 2026-11-08 — offline lab (QEMU ARM64, kernel 4.14.116)

- Built the vendor kernel from source with a QEMU-virt configuration: nine source-level adaptations are documented in `patches/` (all are vendor portability bugs or duplicated declarations, none touch the timer code).
- Booted a minimal initramfs to a clean `INIT_OK`; zero KASAN/panic/WARN in the boot log.
- Wrote a race trigger for CVE-2025-38352 (POSIX CPU timers): `timer_create(CLOCK_THREAD_CPUTIME_ID)` + stall timers, `ptrace`/`waitpid` to reap the task mid-tick, and `timer_delete` from a sibling thread.
- Control run: 5,866 attempts, 2,996 deletes, **0 `TIMER_RETRY`** (`spins=0`), 0 warnings.
- Instrumented runs: a diagnostic kernel printed `del-null` / `run-exiting` / `run-nosighand`; a widening patch added `mdelay()` after `unlock_task_sighand()`. The diagnostic kernel proved the window exists (40 ticks processed the firing list on an `EXIT_ZOMBIE` task), but no delete ever observed `firing=1`.
- A/B with signalfd + epoll amplification (up to 5,000 wait-queue entries) and delete delays of 400/1,200 µs: still `spins=0`, still 0 WARN/KASAN.
- Verdict: `NOT_REPRODUCED`. The remaining gap is timing phase in TCG, not a missing kernel bug.

## 2026-11-15 — GhostLock source audit

- Confirmed `remove_waiter()` in `kernel/locking/rtmutex.c` matches the vulnerable upstream shape; diffed against fix `3bfdc63936dd`.
- Found the Huawei-specific gate: `CONFIG_HW_FUTEX_PI` substitutes `RT_MUTEX_MIN_CHAINWALK` when `hw_futex_pi_enabled == 3`; the sysctl is 0600 and SELinux-confined to `zygote`, so it cannot be flipped from an app.
- Recorded trigger/prerequisite analysis and the remaining obstacles (CFI, HHEE/HKIP, KASLR leak surface closed) as `SOURCE_CONFIRMED` without a chain.

## 2026-11-15 — framework audit (Maple AOT)

- Established that `services.jar` is a 183-byte stub and server code is compiled into `libmapleservices.so` / `libmapleframework.so`.
- CVE-2026-45528: method first appears in Android 13; absent from the Android 10 base and from device binaries → `NOT_APPLICABLE`.
- CVE-2026-0065: class first appears in Android 12; absent from AOSP 10 window-manager sources and from device binaries; method-name strings exist in the Maple library but no equivalent implementation was confirmed → `NOT_APPLICABLE` (class level), `UNKNOWN` (equivalent logic).
- CVE-2026-28614: AOSP Settings class not found in branches 13–16/main and not in the device `Settings.apk`; the device ships the AndroidX variant whose activity is non-exported → `NOT_APPLICABLE`.
- Recorded Maple layout, analysis method and limits in RESEARCH.md §10.

## 2026-11-15 — archiving and publication

- Consolidated the above into this public repository (v1.1.0), regenerated `MANIFEST.sha256`, ran a secret scan over the full history and verified the published tree hashes.
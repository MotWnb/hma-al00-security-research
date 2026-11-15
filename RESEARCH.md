# RESEARCH — Kirin 980 / HarmonyOS 4.0 root feasibility

This is the technical record of the study. It is written so that every conclusion can be re-derived: file paths, function names, line numbers, config symbols, and the exact commands that produced device evidence.

Grades: `SOURCE_CONFIRMED`, `CONFIG_CONFIRMED`, `ACCESS_CONFIRMED`, `REPRODUCED`, `NOT_REPRODUCED`, `INCONCLUSIVE` (see [README](README.md#1-what-this-is)).

Environment: device HMA-AL00, HarmonyOS 4.0.0, patch 2024-02-01, kernel 4.14.116 (vendor source: 2024-01-24). Lab: QEMU 10.2.1 + aarch64 GCC 9.2.1, vendor tree built out-of-tree.

---

## 1. Boot chain and trust root

```
BootROM (mask ROM, immutable)
  └─ xloader (signed, anti-rollback counter in eFuse)
      └─ fastboot / UEFI-ish loader  → verifies boot.img
          └─ kernel + ramdisk       → dm-verity (vbmeta, enforcing)
              └─ HHEE (EL2)         → HKIP: SELinux protection, code XOM, CFI hardening
                  └─ Android/HarmonyOS userspace (SELinux enforcing, FBE)
```

`SOURCE_CONFIRMED` / `CONFIG_CONFIRMED`: the vendor tree contains `CONFIG_HHEE=y`, `CONFIG_HKIP_PRMEM=y`, `CONFIG_HKIP_XOM_CODE=y`, `CONFIG_HKIP_CFI_HARDEN=y`, `CONFIG_HKIP_SELINUX_PROT=y` (8 MB POLDB), `CONFIG_HKIP_ATKINFO=y`, `CONFIG_HKIP_PROTECT_BPF=y`. `CONFIG_HKIP_PROTECT_CRED` is **not** set.

Consequence: even with kernel code execution, disabling SELinux or rewriting `cred` is not a two-line payload; it has to survive EL2 checks. This is why every kernel-bug route below is described as "memory corruption possible in principle, root unproven".

## 2. Bootloader unlock landscape

### 2.1 Official channel — dead

Huawei closed the unlock-code service in 2018, before the Mate 20 launched (October 2018). `ro.oem_unlock_supported=1` is a capability flag; there is no server-side code path and no `fastboot oem unlock` implementation that accepts a code on this generation.

`CONFIG_CONFIRMED`: `ro.boot.flash.locked=1`, `ro.boot.vbmeta.device_state=locked`, `ro.boot.verifiedbootstate=green`.

### 2.2 Testpoint / BootROM USB — works, needs disassembly

The publicly documented method for Kirin 710/970/980 is a BootROM USB exploit driven by the closed-source **Kirin-Tool**, triggered by shorting testpads (or, on older patch levels, a "software testpoint"). The exploit is firmware-independent because it runs in BootROM, which is why it still works on HarmonyOS-era devices.

This was **excluded by the owner** (no teardown). It remains the only publicly demonstrated Kirin 980 unlock.

### 2.3 Software testpoint (SWTP) — patch level too high

The SWTP route requires a security patch level ≤ 2021-01 and a matching offline update package. This device is at 2024-02-01. No downgrade below the anti-rollback floor is possible with publicly available signed packages; community reports of HarmonyOS 3 → 2 → EMUI 10.1 downgrades all stop at the vendor's rollback barrier.

### 2.4 Already-unlocked-BL routes

KernelSU/APatch/Magisk all require writing `boot`/`init_boot`, which a locked bootloader refuses. Projects that ship prebuilt KernelSU kernels for Huawei devices (e.g. `KernelSU_on_Huawei`) require an unlocked BL and do not list HMA-AL00.

## 3. Kernel configuration — the decisive negative evidence

`CONFIG_CONFIRMED` from `/proc/config.gz` (excerpt: [KERNEL_CONFIG/device-config-relevant.txt](KERNEL_CONFIG/device-config-relevant.txt)):

```
# CONFIG_NAMESPACES is not set          <-- every namespace is compiled out
CONFIG_MODULE_SIG=y
CONFIG_MODULE_SIG_FORCE=y
CONFIG_MODULE_SIG_ALL=y
CONFIG_MODULE_SIG_KEY="huawei_signing_key.pem"
# CONFIG_SECURITY_SELINUX_DEVELOP is not set
# CONFIG_FORTIFY_SOURCE is not set
CONFIG_ARM64_PAN=y
CONFIG_RANDOMIZE_BASE=y
CONFIG_HARDENED_USERCOPY=y
CONFIG_CC_STACKPROTECTOR_STRONG=y
CONFIG_SECCOMP=y  CONFIG_SECCOMP_FILTER=y
```

`REPRODUCED` (runtime, `shell`):

```
unshare -Ur id  -> unshare: Invalid argument
unshare -U  id  -> unshare: Invalid argument
/proc/self/uid_map        -> does not exist
/proc/sys/user/max_user_namespaces -> unreadable
CapEff=0000000000000000   CapBnd=00000000000000c0
```

This removes the single most common Android-kernel privilege-escalation class outright, and it is not a patch-level question: the feature is absent from the build.

`CONFIG_MODULE_SIG_FORCE=y` removes loadable-module tricks, and the signing key is Huawei's.

## 4. Attack-surface audit

### 4.1 Huawei HWLOG family — real bugs, unreachable

`SOURCE_CONFIRMED` in `drivers/staging/android/hwlogger/hw_logger.c`, `drivers/hwzerohung/`, `drivers/hwmemcheck/`, `drivers/hwfdleak/`:

* `logger_ioctl()` (`hw_logger.c:722`) only forwards `zrhung_ioctl` / `fdleak_ioctl` / `erecovery_ioctl` / `memcheck_ioctl` when the misc device is `hwlog_exception` (`LOGGER_LOG_EXCEPTION`, `include/chipset_common/hwlogger/hw_logger.h:82`). `hwlog_dubai` and `hwlog_jank` do **not** dispatch them.
* CVE-2022-22252's root cause is still present verbatim: `hcfgk_set_cfg()` (`drivers/hwzerohung/zrhung_config.c:97-178`) drops the lock, `vmalloc`+`copy_from_user`, re-locks, swaps `ctx.user_table`, re-checks `cfg_feature`, and on failure `vfree()`s the *old* table without updating `ctx.table.*`. `hcfgk_set_feature()` (`:293-309`) writes the global gate with no privilege check, so the race window is openable.
* CVE-2022-22256's `%pS` formatting is still present: `memcheck_bufmgr.c:321` `snprintf(buf + used, total - used, "%pS %zu\n", list[i].caller, list[i].ref)`, and `kernel/kallsyms.c:440-441` falls back to a raw `0x%lx` when a symbol lookup fails.

Why it does not matter here — `ACCESS_CONFIRMED` on the device with a purpose-built static aarch64 probe (`shell`, `u:r:shell:s0`):

| Device | open | `0xae01` | `0xab02` | `0xab03` | `0xab04` | `0xab08` | `0xab09` |
|---|---|---|---|---|---|---|---|
| `/dev/hwlog_exception` | OK | `EACCES` | `EACCES` | `EACCES` | `EPERM` | `EACCES` | `EFAULT` |
| `/dev/hwlog_dubai` | OK | 262144 | `EINVAL` | `EINVAL` | `EINVAL` | `EINVAL` | `EINVAL` |
| `/dev/hwlog_jank` | OK | 65536 | `EINVAL` | `EINVAL` | `EINVAL` | `EINVAL` | `EINVAL` |

The DAC mode `0662` does not stop the calls — SELinux does. `plat_sepolicy.cil` grants `(allow domain exception_device (chr_file (ioctl ...)))` but adds an `allowxperm` whitelist:

```
(allowx domain exception_device (ioctl chr_file (0xab01 0xab04 0xab09)))
(allowx domain exception_device (ioctl chr_file (0xad01)))
(allowx domain exception_device (ioctl chr_file ((range 0xaf06 0xaf07))))
(neverallowx ... exception_device (ioctl chr_file ((range 0xab02 0xab03) (range 0xab05 0xab08))))
```

Empirically, the generic `allow ... ioctl` does **not** override `allowxperm`: `SET_HCFG`/`SET_FEATURE` return `EACCES` despite the allow rule. The reachable commands (`0xaf06`/`0xaf07`) only *store* user data (`vzalloc` + `copy_from_user`), they never format `%pS`. The 2022 TASZK primitive is therefore structurally removed, not merely patched.

`untrusted_app` is worse off: `plat:24745` grants it only `(write lock append map open)` on `exception_device`, no `ioctl` at all.

### 4.2 Mali Bifrost kernel driver — fixes backported

`SOURCE_CONFIRMED` in `drivers/gpu/arm/bifrost-r18p0-01rel0` (selected because `CONFIG_MALI_NORR=y`):

* `mali_kbase_mem.c:3833`: `write = reg->flags & (KBASE_REG_CPU_WR | KBASE_REG_GPU_WR);` — CVE-2022-22706 fix present.
* `kbase_mem_from_user_buffer()` (`mali_kbase_mem_linux.c:1505`) carries the same `write` tracking — CVE-2021-28664 class addressed.
* `kbase_vmap_prot()` exists (`mali_kbase_mem_linux.c:2977`).
* `kbase_tracking_page_setup()` (`mali_kbase_mem_linux.c:3084`) starts with `if (vma_pages(vma) != 1) return -EINVAL;` — the key mitigation for CVE-2023-4211.

Conclusion: no known public Mali kernel bug applies to this exact driver revision.

`ACCESS_CONFIRMED`: `/dev/mali0` is `crw-rw-rw- … gpu_device 10,116`, and `shell` can `open()` it. That is the *only* privileged kernel interface a plain shell can open. It is covered by the "no known bug applies" finding, not by an access restriction.

### 4.3 NPU — not built

`CONFIG_CONFIRMED`: `drivers/hisi/Makefile:3 NPU_CUT_MAKEFILE := yes`, the conditional body at `:80-81` is empty, `# CONFIG_NPU_DEVDRV is not set`, and `drivers/hisi/npu/` does not exist in the published tree. `ACCESS_CONFIRMED`: no `/dev/davinci0`. The CVE-2021-22388 / CVE-2021-22412 NPU bugs are therefore absent, not merely fixed.

### 4.4 Binder / framework

`INCONCLUSIVE`. The vendor framework JARs are stubs (`services.jar` = 183 B); the real code is in `oat/arm64/*.odex` + `vdex`, so a full framework audit requires vdex extraction and decompilation. Four Huawei framework CVEs were examined (CVE-2023-52719 PMS, CVE-2024-36500 AMS, CVE-2024-56449 Account, CVE-2025-31170 security-verification): all are genuine Huawei PSIRT advisories naming HarmonyOS 4.0.0, all postdate the device's patch level — and **none has public technical detail, a PoC, or a described root primitive**. They are recorded as open questions, not as a route.

### 4.5 Update chain / recovery

`SOURCE_CONFIRMED` via the TASZK update-chain work:

* CVE-2021-40045 (ZIP EOCD confusion, `≤62 KB` smuggling between comment and signature, `update-binary` executed as root) — fixed 2022-02.
* CVE-2022-44563 (SD-update time-of-check/time-of-use, modified `g_mass_storage` gadget) — fixed 2022-11.
* CVE-2021-40055 (HOTA remote variant) — same family.

All fixes predate 2024-02-01, and the vendor's rollback protection blocks downgrade to a vulnerable build. eRecovery's verification chain (`DoSecVerifyFromZip → huawei_signature_and_auth_verify → hw_map_and_verify_package → Verify::Verify → IsSdRootPackage → hw_update_auth_verify → CheckBoardIdInfo → USBUpdateVersionCheck`) is intact in the published binaries.

### 4.6 UVC (`CVE-2024-53104`) — code bug, unreachable

`SOURCE_CONFIRMED`: `drivers/media/usb/uvc/uvc_driver.c:534` still reads

```c
while (buflen > 2 && buffer[1] == USB_DT_CS_INTERFACE &&
       buffer[2] == ftype) {
```

without the upstream `ftype &&` guard; the DV branch sets `ftype = 0` at `:503`, so a `UVC_VS_UNDEFINED` frame descriptor can write past the `format->frame[]` array allocated in `uvc_parse_streaming()`.

`CONFIG_CONFIRMED`: `CONFIG_USB_VIDEO_CLASS=y`; `/dev/video0..4` exist.
`ACCESS_CONFIRMED`: `(neverallow appdomain video_device (chr_file (read write)))`; only `hal_camera`, `mediaserver`, `surfaceflinger`, `system_server` hold `video_device` permissions.

Requires physical USB device **and** a camera-domain process ⇒ not an app-to-kernel path.

### 4.7 Futex PI (`CVE-2026-43499`, "GhostLock")

`SOURCE_CONFIRMED`: `kernel/locking/rtmutex.c:1100-1144 remove_waiter()` still clears `current->pi_blocked_on` / `current->pi_lock` for the requeuer instead of `waiter->task`, and `rt_mutex_start_proxy_lock()` (`:1838-1851`) calls it on `-EDEADLK`.

`CONFIG_CONFIRMED`: `CONFIG_FUTEX_PI=y`, `CONFIG_HW_FUTEX_PI=y`. Vendor gate `is_hw_futex_pi_enabled()` (`include/chipset_common/linux/hw_pi.h:39-46`) is `(g & 3) == 3`; `futex_init()` (`kernel/futex.c:4215-4217`) initialises it to `0x1`, so the proxy path uses `RT_MUTEX_FULL_CHAINWALK` and deadlock detection stays on ⇒ the `-EDEADLK` rollback is reachable. The only writer is the sysctl `kernel.hw_futex_pi_enabled` (0600 root, `kernel/sysctl.c:433-440`).

Why no root: this is a *use-after-return* of a kernel stack frame. Turning it into a write requires (a) reclaiming the freed stack frame, (b) a controlled `rb_erase`/`rt_mutex` object, (c) a KASLR disclosure, and (d) CFI-compatible control flow. The public Android chain uses `ashmem`→`configfs` same-signature `read_iter/write_iter` (CFI), a `boot_id`-based `.data` read for KASLR, and a `pipe_buffer` physical R/W upgrade — none of which was validated on this device. Additionally this build has `CONFIG_CFI_CLANG=y` with shadow and `CONFIG_UNMAP_KERNEL_AT_EL0` **not** set (no KPTI), which changes both the leak and the trampoline assumptions.

Verdict for the four stages: presence **yes**, trigger conditions **likely**, memory write **plausible but unproven**, UID 0 **no**.

### 4.8 POSIX CPU timers (`CVE-2025-38352`) — the most promising candidate

`SOURCE_CONFIRMED`, `kernel/time/posix-cpu-timers.c`:

* `run_posix_cpu_timers()` `:1123-1181`: `WARN_ON_ONCE(!irqs_disabled())` at `:1129`; `lock_task_sighand()` `:1138`; `check_thread_timers()` `:1145`; `check_process_timers()` `:1147`; **`unlock_task_sighand()` `:1157`**; then `list_for_each_entry_safe(timer, next, &firing, it.cpu.entry)` `:1165`, `spin_lock(&timer->it_lock)` `:1168`, `list_del_init` `:1169`, `cpu_timer_fire()` `:1177`. **No `exit_state` check anywhere** — the upstream fix (`f90fff1e152d`, "if (tsk->exit_state) return;") is absent.
* `posix_cpu_timer_del()` `:370-403`: `lock_task_sighand(p)` `:383`; on `NULL` it only does `WARN_ON_ONCE(!list_empty(&timer->it.cpu.entry))` `:389` and returns `ret = 0`, so the caller frees the timer while it may still be on the IRQ's firing list; `:400 put_task_struct(p)`.
* `__exit_signal()` (`kernel/exit.c`) sets `tsk->sighand = NULL` at `:164`, after `posix_cpu_timers_exit()` at `:105`.

`CONFIG_CONFIRMED`: `CONFIG_POSIX_TIMERS=y`, `CONFIG_HIGH_RES_TIMERS=y`, `CONFIG_HZ=1000`. `CONFIG_POSIX_CPU_TIMERS_TASK_WORK` **does not exist in this tree** (grep returns 0 hits, including `posix_cputimers_work`), so the "task_work variant is unaffected" branch of the fix does not apply — only the vulnerable path exists.

`ACCESS_CONFIRMED`: the syscalls are available to an app UID, and the CVE text itself states "any unprivileged local user, including a seccomp-confined Android app UID".

This is the only candidate that satisfies *code present + config on + reachable from an ordinary app*. Stage A (offline reproduction) is described next.

## 5. Stage A — offline QEMU reproduction

Goal: prove the UAF on the **vendor's own tree**, without touching the phone.

Setup: QEMU 10.2.1 `-M virt -cpu cortex-a72 -smp 4 -m 3072`, vendor 4.14.116 tree, aarch64 GCC 9.2.1, KASAN outline, `CONFIG_RANDOMIZE_BASE` off (lab only), `PREEMPT=y`, `HZ=1000`.

Nine build adaptations were required — they are all in [patches/](patches/README.md) and **none touches the timer code**. Two of them are vendor bugs that would also affect a real device build (`elevator_exit` self-recursion, PSCI conduit hard-coded to SMC).

Boot: `INIT_OK`, zero KASAN/panic/warns ([logs/sanitized/boot-clean.excerpt.log](logs/sanitized/boot-clean.excerpt.log), `REPRODUCED`).

Trigger: derived from the public `chronomaly` choreography — racer thread arms `CLOCK_THREAD_CPUTIME_ID` timers and burns CPU until just before expiry, then returns; a free thread catches the signal via `signalfd` and calls `timer_delete()`; the parent `ptrace`s the racer and reaps it to drive `__exit_signal()` concurrently.

Results (`REPRODUCED` for the counters, `NOT_REPRODUCED` for the bug):

| Run | Tries | Fires | "delete after reap" | `WARN_ON_ONCE` | KASAN |
|---|---|---|---|---|---|
| v1 (blocking `poll` wake) | 5,300 | 2,847 | 1,000 | 0 | 0 |
| v2 (`SFD_NONBLOCK` busy poll, `MARGIN_NS=60000`) | 5,600 | 2,332 | 1,531 | 0 | 0 |
| v2, 60 s cap + full stats | 2,367 | 952 | 295 | 0 | 0 |

`STATS attempts=952 ok=952 einval=0 spins=0`: not once did a delete hit the `TIMER_RETRY` path (`firing=1`), i.e. the timer had never been left on the firing list by the IRQ at the moment of deletion. The "wins" only mean "deleted after reap", by which time the IRQ had already `list_del_init`-ed the entry.

Diagnostic kernel (`REPRODUCED`): three temporary `pr_warn()` probes showed

* `del-null` 40/40 with `entry_empty=1 firing=0` — the deleter sees `sighand == NULL` but the list is already empty;
* `run-nosighand` 38 samples with `exit_state=16` (`EXIT_DEAD`);
* `run-exiting` 40/40 with `exit_state=32` (`EXIT_ZOMBIE`) and `fired=1` — **the window is real**: a zombie's tick does process a non-empty firing list after `unlock_task_sighand()`.

Instrumented kernels (`NOT_REPRODUCED`): delaying after `unlock_task_sighand()` does not help, because the free thread is only woken by `send_sigqueue()` inside `cpu_timer_fire()`, i.e. *after* the loop. A second variant that delays inside the loop after the first `cpu_timer_fire()` also produced 0 hits (`spins=0`, 685 attempts).

Verdict: the vulnerability is present in the shipped source; a reliable reproduction on this kernel/QEMU combination was **not** achieved. The remaining gap is scheduling-shape, not code: to win, the tick must land after `exit_notify()` and before the reclaim completes, with the deleter already inside `posix_cpu_timer_del()`.

## 6. Why the answer is still "no root"

| Layer | What blocks it |
|---|---|
| Bootloader | Locked; only BootROM/testpoint unlocks, which needs hardware access. |
| Kernel config | No namespaces, no module loading, SELinux without `DEVELOP`, PAN, KASLR, stack protector. |
| SELinux | `allowxperm` whitelists remove the reachable Huawei ioctl surface; `untrusted_app` cannot even get `ioctl` on `hwlog_exception`. |
| Hypervisor | HHEE/HKIP protects SELinux policy and code; disabling SELinux from kernel is not sufficient. |
| Exploit engineering | The two live candidates (GhostLock, CVE-2025-38352) need KASLR disclosure + CFI bypass + reliable stack-frame control; no public ARM64 4.14 chain exists. |

## 7. What would change the conclusion

1. The owner allows **teardown** → Kirin-Tool testpoint path becomes available (the only publicly demonstrated unlock).
2. A **signed** downgrade package below the 2021-01 patch level appears → SWTP becomes possible.
3. A public **ARM64 4.14** chain for GhostLock or CVE-2025-38352 appears, including a KASLR leak that works with `CFI_CLANG` and without KPTI.
4. A framework-level (Binder/AMS/PMS) bug with a described root primitive is published — currently all four Huawei CVEs are text-only advisories.

## 9. Framework audit (2026-11-15): three 2026 CVEs

### 9.1 A structural finding that changes how the framework must be read

Before judging any framework CVE on this device, one fact has to be established: **the server-side Java code is not shipped as DEX**.

* `/system/framework/services.jar` is **183 bytes** (only `META-INF/MANIFEST.MF`).
* `/system/framework/oat/arm64/` contains **no `services.odex`**; its 85 entries are at most 123,880 bytes.
* `/system/framework/boot-zframework.z.vdex` is 15,505,108 bytes, header `vdex021`, `number_of_dex_files=2`, `dex_size=0x5450` (**21,584 bytes**) — the DEX payload is negligible.
* The actual implementations live in Huawei's **Maple AOT** native libraries: `/system/lib64/libmapleservices.so` (37,359,880 B) and `/system/lib64/libmapleframework.so` (87,774,536 B).

Consequences: a string search over ODEX/VDEX/JAR **cannot** establish absence of a framework method on this build. Runtime component presence must be checked separately — `service list` reports `mount: [android.os.storage.IStorageManager]`, so the StorageManager service itself is present (`COMPONENT_PRESENT`).

### 9.2 CVE-2026-45528 — `StorageManagerService.getManageSpaceActivityIntent`

| Item | Result |
|---|---|
| AOSP 10.0.0_r47 `StorageManagerService.java` | Method **absent** (file is 152,164 B at `services/core/java/com/android/server/StorageManagerService.java`) |
| Introduction point | Present from **Android 13** (`android-13.0.0_r1`, `android-14.0.0_r1`; `main` line 3530) |
| Device base | `QP1A.190711.020` (API 29) |
| Device binary strings | `StorageManagerService` 0, `getManageSpaceActivityIntent` 0, `getManageSpace` 0 across `/system`, `/system_ext`, `/vendor`, `/product` (>100 KB files) |
| Grade | `COMPONENT_PRESENT`; `CODE_PRESENT` = not found; verdict **`NOT_APPLICABLE`** (medium-high confidence) |

Residual uncertainty: Maple output may strip or rewrite Java method names. The 37 MB library was not disassembled; a vendor backport cannot be excluded with 100 % certainty.

### 9.3 CVE-2026-0065 — `BackgroundLaunchProcessController.areBackgroundActivityStartsAllowed`

| Item | Result |
|---|---|
| Class introduction | **Android 12**; AOSP 10 `services/core/java/com/android/server/wm/` (151 files) has **no** `Background*` class |
| Device binary strings | `BackgroundLaunchProcessController` 0; `areBackgroundActivityStartsAllowed` 2 hits and `BackgroundActivityStart` 6 hits in `libmapleservices.so` |
| Grade | Class level **`NOT_APPLICABLE`**; whether an equivalent, bypassable check exists = **`UNKNOWN`** |

The two string hits show Huawei has its own background-activity-start logic, but they do not prove the Android 12 class (or a backport of it) is present.

### 9.4 CVE-2026-28614 — `SlicePermissionActivity.onCreate`

* The AOSP Settings class `com.android.settings.slices.SlicePermissionActivity` was not found in the enumerable branches `android-13.0.0_r1`, `android-14.0.0_r1`, `android-15.0.0_r1`, `android-16.0.0_r1`, `main`, and it is **not** in the device's `Settings.apk`.
* The device does ship an AndroidX class of the same short name: `androidx.slice.compat.SlicePermissionActivity` (in `classes73.dex` of `Settings.apk`). Decompiled `onCreate` reads `EXTRA_BIND_URI`, `EXTRA_PKG` and `EXTRA_PROVIDER_PKG` from the intent, and on "allow" calls `SliceProviderCompat.grantSlicePermission(this, getPackageName(), mCallingPkg, uri)` — it does **not** verify the real caller, which is the shape of a confused deputy.
* It is nevertheless not reachable by other apps: in `AndroidManifest.xml` (line 9436) the activity has **no intent-filter** and `excludeFromRecents=true`, so under API 29 rules `exported=false`.
* Grade: target class **`NOT_APPLICABLE`**; the AndroidX grant path is recorded as an **independent observation**, not as this CVE.

### 9.5 Combined verdict

None of the three CVEs has `CODE_PRESENT` or `ACCESS_CONFIRMED` on this device, and none yields a "normal app → system privilege" path. The dominant uncertainty is Maple AOT; resolving it would require disassembling tens of megabytes of vendor native code for a bug class that postdates the device base by three Android generations.

### 9.6 balong_modem.ko differential — assessment only

`/vendor/modem/modem_driver/balong_modem.ko` (11,721,784 B, SHA-256 `BACAAE2042EAF7A615185DB51E74E2443027525A376E98FD99CAFC5D13199`) exposes `misc_register` ×2, `copy_from_user` ×4, `copy_to_user` ×5 and 35 `ioctl` strings; `sw.ko` (192,240 B) has no ioctl/copy surface. CVE-2026-34854/34855 are rated `AV:L/AC:H/PR:H` — they require existing high privilege and cannot serve as an initial escalation step. A meaningful differential would need a newer HMA-AL00 firmware (existence unconfirmed) plus disassembly of an 11.7 MB stripped module. Recommendation: **not a root route**; completeness-only, and only if an update package becomes available.

## 10. Maple AOT: what it is and why it breaks naive analysis

### 10.1 Layout observed on this device

| Path | Size | Role |
|---|---|---|
| `/system/framework/services.jar` | 183 B | Stub; manifest only |
| `/system/lib64/libmapleservices.so` | 37,359,880 B | Maple-compiled server-side implementations |
| `/system/lib64/libmapleframework.so` | 87,774,536 B | Maple-compiled framework implementations |
| `/system/framework/boot-zframework.z.vdex` | 15,505,108 B | `vdex021`; DEX payload 21,584 B (mostly verifier metadata) |
| `/system/framework/oat/arm64/*.odex` | ≤123,880 B each | Thin/skeleton artifacts for non-server libraries |

Maple is Huawei's ahead-of-time translator that lowers Java bytecode to native code for HarmonyOS. On this build it is applied to core services, so the usual Android artefacts (`services.dex`, `services.odex`, `services.vdex`) are absent or empty.

### 10.2 Why ODEX/VDEX string searches mislead

1. The DEX string pool for server classes is not on disk in an extractable form; only native code and a small metadata payload remain.
2. Java method names are not guaranteed to survive: they may be inlined, deduplicated, or omitted together with reflection metadata.
3. Conversely, the presence of a method-name string in a `.so` does not prove an equivalent implementation — it may be a log format, a property name, or a different class.

### 10.3 Analysis method used here (and its limits)

* Establish **component presence** from runtime facts (`service list`, binder interfaces) rather than from files.
* Use AOSP history to establish **when code was introduced** (`android-10.0.0_r47` → `android-13/14` → `main`); a method that first appears after the device base is a strong *not-applicable* signal, though not proof against a vendor backport.
* Treat `.so` string hits as **leads**, not findings.
* For framework classes still shipped as DEX (e.g. `Settings.apk`), decompile and read the bytecode (jadx 1.5.0; `--single-class` keeps output small).
* Limits: no symbol table or debug info in the Maple libraries, aggressive inlining, and no public description of Maple's metadata. Full confirmation would need disassembly (Ghidra/IDA) plus cross-version differential analysis; that is out of proportion for this project.

### 10.4 Implication for future audits of HarmonyOS 3/4 devices

Any framework-CVE triage on these builds must start from the native libraries, not from ODEX/VDEX. Absence of a class in `/system/framework/oat/` and in `services.jar` is **not** evidence of absence. This is the single most reusable lesson from this round.

## 11. References

* Huawei open-source portal — `HMA-AL00-TL00_HarmonyOS4.0.0` (see [SOURCE_PROVENANCE](SOURCE_PROVENANCE.md)).
* XDA: permanent bootloader unlock for Kirin 710/710F/970/980 — `xdaforums.com/t/…4768171/`.
* TASZK Security Labs: hwlog UAF (CVE-2022-22252), memcheck leak (CVE-2022-22256), HHEE/HKIP bypass (2025).
* `farazsth98/chronomaly` — CVE-2025-38352 exploit for x86_64 5.10 (race choreography reference only).
* Google Project Zero: Mali `kbase` RCAs (CVE-2021-39793, CVE-2022-22706, CVE-2023-4211).
* Android 10 `bionic` seccomp policy sources (AOSP `android10-release`).
* NVD / Huawei PSIRT advisories for the four framework CVEs and the DFX CVEs.

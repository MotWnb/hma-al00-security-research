# TODO / status

```
RESEARCH_STATUS: PAUSED
ROOT_STATUS:     NOT_ACHIEVED
LAST_REVIEWED:   2026-11-15
```

The investigation is paused: every reachable software-only route has been checked to the level the evidence allows, and the remaining paths require either disassembly (hardware) or vendor-side changes. Nothing below is a claim of exploitation.

## Route status

| Route | Status | Note |
|---|---|---|
| Official bootloader unlock code | Dead | Vendor service closed in 2018 |
| `fastboot` unlock while locked | Rejected by design | `vbmeta` locked, `flash.locked=1` |
| Testpoint / BootROM USB unlock | Works, needs disassembly | Out of scope by owner constraint |
| Software testpoint (SWTP) | Not applicable | Requires patch level ≤ 2021-01; device is 2024-02-01 |
| Downgrade below anti-rollback | Blocked | No signed downgrade path found |
| Magisk / KernelSU / APatch | Requires unlocked BL | Installation path cannot start |
| Kernel CVE route (hwlog/DFX) | Dead | Code present, `allowxperm` policy blocks every reachable ioctl |
| Kernel CVE route (POSIX CPU timers, CVE-2025-38352) | `NOT_REPRODUCED` | Offline QEMU lab, 5,500+ attempts, 0 WARN / 0 KASAN |
| Kernel route (GhostLock, CVE-2026-43499) | `SOURCE_CONFIRMED`, no chain | Gate sysctl unreadable/unwritable from app; CFI + HHEE remain |
| Framework CVEs (2026-45528 / 0065 / 28614) | `NOT_APPLICABLE` | Target classes/methods not present on the Android 10 base |

## Open / UNKNOWN items (deliberately not closed)

- **CVE-2026-0065** — the method name `areBackgroundActivityStartsAllowed` exists in `libmapleservices.so`, but an equivalent implementation was not confirmed; `UNKNOWN`, not "vulnerable".
- **CVE-2026-34854 / 34855** — `balong_modem.ko` has an ioctl/copy surface, but no source-level evidence of either bug; `UNKNOWN`.
- **CVE-2025-38352** — source-level root cause confirmed in 4.14.116 (`run_posix_cpu_timers()` has no `exit_state` check), yet the offline experiment never reached the window: `NOT_REPRODUCED`.
- **CVE-2026-43499 (GhostLock)** — source-level root cause confirmed (`remove_waiter()` clears the wrong task's `pi_blocked_on`), but no complete chain: the gate sysctl `/proc/sys/kernel/hw_futex_pi_enabled` is 0600 and confined to `zygote`, and CFI + HHEE/HKIP protection remain.
- **Maple AOT** — whether Huawei back-ported any post-Android-10 framework fix into the native libraries cannot be settled without disassembly.

## Not to be done without new evidence

- Do not run race or exploit code on the physical device.
- Do not flash, unlock, downgrade or wipe; the device is the only sample.
- Do not present a `SOURCE_CONFIRMED` bug as a working exploit.
# security/selinux — policy excerpts and ioctl access audit

The device runs SELinux in enforcing mode with compiled policy version 310. Three policy files were pulled read-only:

| File | Size | Role |
|---|---|---|
| `/system/etc/selinux/plat_sepolicy.cil` | 2,091,772 B | platform policy (AOSP + Huawei) |
| `/vendor/etc/selinux/vendor_sepolicy.cil` | 575,364 B | vendor policy |
| `/system/etc/selinux/plat_pub_versioned.cil` | 795,648 B | versioned public types |

Only short excerpts are published (in [policy-excerpts.txt](policy-excerpts.txt)); the full files are withheld as they are large compiled artifacts.

## Why this matters for the study

Two questions decided several CVE verdicts:

1. **Can `shell` or `untrusted_app` reach the Huawei ioctl surface?** No. The generic `(allow domain exception_device (chr_file (ioctl ...)))` looks permissive, but the `allowxperm` whitelist is what actually governs:
   * allowed: `0xab01`, `0xab04`, `0xab09`, `0xad01`, `0xaf06`–`0xaf07`;
   * `neverallowx`: `0xab02`–`0xab03`, `0xab05`–`0xab08` (this is `SET_HCFG`, `SET_HCFG_FLAG`, `SET_FEATURE`, …).
2. **What can `untrusted_app` do?** It has no `ioctl` on `exception_device` at all, only `write/lock/append/map/open`. The four Huawei framework CVEs would have to be reached through Binder, not through these devices.

Empirical confirmation (`ACCESS_CONFIRMED`, static aarch64 probe as `shell`): `0xab03` and `0xab08` return `EACCES` despite the `allow … ioctl` rule; `0xab09` returns `EFAULT` (the check passed and the driver was entered); `0xae01` is denied on `exception` but allowed on `dubai`/`jank`.

## Domains compared

| Domain | `exception_device` | `dubai_log_device` | `gpu_device` | `video_device` |
|---|---|---|---|---|
| `shell` (in `domain`) | open+ioctl (whitelisted only) | open+ioctl (no allowx ⇒ all) | no direct allow found | no |
| `untrusted_app` (targetSdk 29) | open/write only, **no ioctl** | no | via attribute sets only | `neverallow` |
| `untrusted_app_25` / `_27` | — | — | — | — |
| `zygote` | — | — | — | — |
| `system_server` | `0xaf01`, `0xaf03` | — | yes | yes |
| `logserver` | `0x0000`–`0xffff` | — | — | — |

## The futex gate is a SELinux object too

`hw_futex_pi_enabled` is labelled `proc_hw_futexpi`; only `zygote` can read/write it:

```
(genfscon proc /sys/kernel/hw_futex_pi_enabled (u object_r proc_hw_futexpi ((s0) (s0))))
(allow zygote proc_hw_futexpi (file (read write getattr open)))
```

`shell` gets `Permission denied`, which is why the runtime value of the GhostLock gate could not be measured (it is initialised to 0x1 at boot; see [../cve/CVE-2026-43499.md](../cve/CVE-2026-43499.md)).

## Note on `/dev/ashmem`

`ashmem_device` is granted to `untrusted_app_25`/`_27` but **not** to `untrusted_app` (targetSdk 29), and `neverallow base_typeattr_573 ashmem_device (chr_file (open))`. Any chain that uses `ashmem` (as the public GhostLock chain does) requires a targetSdk ≤ 27 package on this device.

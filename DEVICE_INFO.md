# Device information (sanitized)

All values below were obtained from the device with **read-only** `adb` commands (`getprop`, `ls -lZ`, `cat /proc/config.gz`, `service list`, `pm list packages`). No identifier that can be linked to the owner or the physical unit is published. See [AUDIT_REPORT.md](AUDIT_REPORT.md) for the redaction rules.

## 1. Identity

| Property | Value |
|---|---|
| `ro.product.model` | `HMA-AL00` |
| `ro.product.device` | `HWHMA` |
| Marketing name | Huawei Mate 20 |
| SoC | Kirin 980 (`ro.boot.hardware=kirin980`) |
| Board / codename in fastboot | `HI3650` (`USB\VID_18D1&PID_D00D`) |
| Serial, IMEI, MEID, MAC, Android ID | **withheld** |

## 2. Software

| Property | Value |
|---|---|
| `ro.build.display.id` | `HMA-AL00 10.1.0.163(C00E160R1P8)` |
| `ro.build.version.release` / `sdk` | `10` / `29` |
| `ro.build.version.emui` | `EmotionUI_14.0.0` |
| `hw_sc.build.platform.version` | `4.0.0` (HarmonyOS 4.0) |
| `hw_sc.build.os.version` / `apiversion` | `2.2.0` / `6` |
| `ro.build.type` / `ro.build.tags` | `user` / `release-keys` |
| `ro.build.version.security_patch` (AOSP) | `2020-07-01` |
| `ro.huawei.build.version.security_patch` (effective) | **`2024-02-01`** (`ro.config.use_hw_security_patch=true`) |
| `ro.build.date` | `Wed Jan 31 12:55:15 CST 2024` |
| Kernel build | `Wed Jan 24 01:16:33 CST 2024`, clang 9.0.3 |
| Kernel version | `Linux 4.14.116` |

The AOSP patch level is misleading: Huawei maintains a separate patch counter and the effective level is 2024-02-01. All applicability judgments in this repository use the Huawei level.

## 3. Boot and verified boot state

| Property | Value |
|---|---|
| `ro.boot.flash.locked` | `1` |
| `ro.boot.verifiedbootstate` | `green` |
| `ro.boot.veritymode` | `enforcing` |
| `ro.boot.vbmeta.device_state` | `locked` |
| `ro.oem_unlock_supported` | `1` (capability flag only; no unlock path) |
| `ro.secure` / `ro.debuggable` / `ro.adb.secure` | `1` / `0` / `1` |
| `ro.crypto.state` / `ro.crypto.type` | `encrypted` / `file` (FBE) |
| SELinux | `Enforcing`, `policyvers 310` |

## 4. Privilege baseline (shell context)

```
uid=2000(shell) gid=2000(shell) context=u:r:shell:s0
CapEff=0000000000000000   CapBnd=00000000000000c0   Seccomp: 0
getenforce                -> Enforcing
adb root                  -> adbd cannot run as root in production builds
adb remount               -> Not running as root
su -c id                  -> /system/bin/sh: su: inaccessible or not found
```

The `shell` domain is a member of `domain` and shares the generic `domain` rules; it is **not** the same as `untrusted_app` (see [security/selinux/README.md](security/selinux/README.md)).

## 5. Partition map (`/dev/block/by-name`, `sdd*`)

| Node | Purpose |
|---|---|
| `sdd40` | `kernel` |
| `sdd52` | `ramdisk` |
| `sdd42` | `recovery_ramdisk` |
| `sdd58` / `sdd59` | `recovery_vbmeta` / `erecovery_vbmeta` |
| `sdd6` | `oeminfo` |
| `sdd19` | `misc` |
| `sdd30` | `fastboot` |
| `sdd63` | `patch` |
| `sdd64`–`sdd67` | `preas` / `preavs` / `prets` / `pretvs` |
| `sdd27`–`sdd29`, `sdd11` | `hisee_img` / `hhee` / `hisee_fs` / `hisee_encos` |
| `sdd71` | `/data` (F2FS, FBE) |

`/` and `/vendor` are EROFS on `dm-*` devices (system-as-root, dynamic partitions). `/proc/partitions` and `/proc/cmdline` are not readable by `shell`.

## 6. Mounted file systems

| Mount | Type | Notes |
|---|---|---|
| `/` | EROFS | read-only, `seclabel` |
| `/vendor` | EROFS | read-only, `seclabel` |
| `/data` | F2FS | read-write, encrypted |

`/system` is readable for file *content* but directory listing under `/system/bin` is denied by SELinux; `/system/framework` is listable.

## 7. Device nodes relevant to the audit

```
crw-rw-rw- system system u:object_r:gpu_device:s0        /dev/mali0        10,116
crw-rw-r-- system system u:object_r:ion_device:s0        /dev/ion          10,126
crw-rw---- root   root   u:object_r:dubai_device:s0      /dev/dubai        10,69
crw-rw--w- root   system u:object_r:dubai_log_device:s0  /dev/hwlog_dubai  10,110
crw-rw--w- root   log    u:object_r:exception_device:s0  /dev/hwlog_exception 10,112
crw-rw--w- root   system u:object_r:jank_device:s0       /dev/hwlog_jank   10,111
crw-rw-rw- root   root   u:object_r:ashmem_device:s0     /dev/ashmem       10,113
crw-rw---- system camera                                 /dev/video0..4    81,0/4/6/8/10
```

No `/dev/davinci0` exists (NPU driver not built). `/dev/kgsl-3d0` does not exist.

## 8. Kernel configuration (excerpt)

The device `/proc/config.gz` is a full 6,754-line configuration; the published excerpt is [KERNEL_CONFIG/device-config-relevant.txt](KERNEL_CONFIG/device-config-relevant.txt). Decisive entries:

```
# CONFIG_NAMESPACES is not set
CONFIG_MODULE_SIG=y            CONFIG_MODULE_SIG_FORCE=y
CONFIG_MODULE_SIG_KEY="huawei_signing_key.pem"
# CONFIG_SECURITY_SELINUX_DEVELOP is not set
# CONFIG_FORTIFY_SOURCE is not set
CONFIG_ARM64_PAN=y             CONFIG_RANDOMIZE_BASE=y
CONFIG_HARDENED_USERCOPY=y     CONFIG_CC_STACKPROTECTOR_STRONG=y
CONFIG_SECCOMP=y               CONFIG_SECCOMP_FILTER=y
CONFIG_CFI=y                   CONFIG_CFI_CLANG=y
CONFIG_HW_FUTEX_PI=y           CONFIG_FUTEX_PI=y
# CONFIG_CHECKPOINT_RESTORE is not set
# CONFIG_UNMAP_KERNEL_AT_EL0 is not set
```

`CONFIG_POSIX_CPU_TIMERS_TASK_WORK` does not exist anywhere in this 4.14 tree.

## 9. Binder services of interest

`service list` returns 260 entries (full list withheld; it contains build-specific names). Security-relevant ones observed:

`system.hsmcore`, `authentication_service`, `SecGuardDataMgr`, `trustcircle_manager_service`, `pluginmanager`, `hwservicebusmanager`, `HwFileMonitorService`, `appassistant`, `deviceinfoex`, `facerecognition`, `voicerecognition`.

## 10. Packages and framework artifacts

* `/system/priv-app`: 108 entries; `/system/app`: 105 entries.
* `moe.shizuku.privileged.api` (Shizuku) is installed — ADB-level privilege only, not root.
* Framework JARs are **stubs**: `services.jar` is 183 B, `hwPartSecurityServices.jar` 22 B, `hwServices.jar` 200 B. Real implementations live in `oat/arm64/*.odex` + `vdex`, so framework analysis requires vdex extraction.
* `framework.jar` (32.4 MB) is AOSP framework code and can be decompiled directly.
* Update-related APKs of interest: `HwOUC.apk` v104.0.0.65, `DUpdateEngine.apk`, `HwSecurityMgrService.apk` (all withheld from this repository).

## 11. Hypervisor / TEE

| Config | Value |
|---|---|
| `CONFIG_HHEE` | `y` |
| `CONFIG_HKIP_PRMEM`, `_XOM_CODE`, `_CFI_HARDEN`, `_SELINUX_PROT`, `_ATKINFO`, `_PROTECT_BPF` | `y` |
| `CONFIG_HKIP_PROTECT_CRED` | not set |
| `CONFIG_HISEE` | `y` |

HHEE is present and enforces SELinux-protection at EL2; any kernel-level "turn off SELinux" step has to survive it.

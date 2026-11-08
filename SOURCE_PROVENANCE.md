# Source provenance and licensing

This document records exactly where every non-original artifact in this repository came from, and under which license it is redistributed — or why it is **not** redistributed.

## 1. Vendor kernel source (the basis of `SOURCE_CONFIRMED` claims)

Huawei is required to publish the GPL-2.0 kernel source it ships. The package used here was obtained from Huawei's public open-source portal, not from a third-party mirror.

| Field | Value |
|---|---|
| Portal | `consumer.huawei.com` → "Open Source Code" download center |
| List API | `https://consumer.huawei.com/cmkt/servlet/file/list?siteCode=worldwide&keywords=Mate%2020&fileType=openSourceSoftware&pageSize=20&curPage=1` (requires a browser `User-Agent`; otherwise HTTP 204) |
| Entry | `HMA-AL00-TL00_HarmonyOS4.0.0` |
| Displayed size / release date | 565.23 MB / 2024-05-15 |
| Direct URL | `https://download-c1.huawei.com/download/downloadCenter?downloadId=A18B1F00980AF0670C2D0315BDFAE6B5&version=A88E5E9746F197403122DF4720184620&siteCode=worldwide` |
| Downloaded file name (as served) | `HMA-AL00-TL00_HormonyOS4.0.0_opensource.tar.gz` (Huawei's own spelling; the file is gzip despite the `.zip` name used locally) |
| Size | 592,682,548 bytes |
| **SHA-256** | `F2FD7D239844A7A52292860413664DA9313A9B2D140D13C825A5E8121B078036` |
| Internal path | `Code_Opensource/kernel/` |
| Version markers | `README_Version.txt`: "This kernel package is released for the phone software version 2024-01-24"; `arch/arm64/configs/merge_kirin980_defconfig`: "# Linux/arm64 4.14.116 Kernel Configuration"; `Makefile`: `VERSION=4 PATCHLEVEL=14 SUBLEVEL=116` |

**License:** GPL-2.0 (Linux kernel). The tarball is **not** redistributed here — it is 592 MB and GPL compliance is already satisfied by Huawei's own download page. `SOURCE_PROVENANCE.md` gives the exact URL, size and hash so anyone can obtain a bit-identical copy.

**Derivative status:** the patches in `patches/` are context-preserving `diff -u` hunks against files from this GPL-2.0 tree. They remain GPL-2.0 and are **not** relicensed. Each patch header records the original path.

## 2. Device artifacts (pulled read-only over ADB; **not redistributed**)

These are Huawei proprietary binaries. They are listed here so that any claim about them can be checked against a known-good hash without publishing the bytes.

| Artifact | Size (bytes) | SHA-256 |
|---|---|---|
| `/vendor/lib64/egl/libGLES_mali.so` | 42,112,752 | `61E9DABC697D97EA628282EC70ECEF331DA55CB10D6AA104F12673E29988CA13` |
| `/system/framework/framework.jar` | 32,394,992 | `CB6E1C17C645F839D5B412ABE1BA7453A3995D688B795CEAB3263CD39390FD93` |
| `/system/lib64/libc.so` | 1,136,552 | `FD3E195ABE970846351C71E47EAA0B3829C69428738C98F1AB45F025495845A6` |
| `/system/app/HwOUC/HwOUC.apk` | 18,925,858 | `735C63CDBDE967D27D9DF5ED2591BD3A58A4D308B469EFD81565D3D6F295C589` |
| `/system/priv-app/DUpdateEngine/DUpdateEngine.apk` | 4,336,472 | `12E663D63018D0F4F139610019340F09CB69EB6ED12DBB9110D9343CFEF124F1` |
| `/system/app/HwSecurityMgrService/HwSecurityMgrService.apk` | 1,127,142 | `1A11D7FD4E05757E77DC15A57072C06ACBD2447AC6C19AD970CD643C6A252631` |
| `/proc/config.gz` (device) | 42,779 | `EDD2A0132432004D1B36F8E5FF2F426C8E5F21E58AB6243085F59596CDD24DF3` |

Redistribution status: **withheld** (copyright; no license to redistribute; also unnecessary for reproducibility of the published claims). The Mali userspace version claim (`r18p0-01rel0`) is reproducible from the hash above by anyone with the same firmware.

## 3. SELinux policy files (excerpts only)

`plat_sepolicy.cil`, `vendor_sepolicy.cil`, `plat_pub_versioned.cil` are compiled artifacts of AOSP/Huawei policy. Only short excerpts needed to justify a specific permission claim are published (see `security/selinux/`). Full files are withheld; they are large and mostly irrelevant.

## 4. Third-party research referenced

| Work | Use | License / status |
|---|---|---|
| `farazsth98/chronomaly` (CVE-2025-38352 exploit, x86_64 5.10) | Read for the **race choreography**; no code copied | Public GitHub repository; not vendored |
| TASZK Security Labs blog series on Huawei hwlog / HHEE | Cross-check of CVE-2022-22252/22256 and HKIP | Public write-ups; quoted briefly with attribution |
| Google Project Zero RCA on Mali `kbase` | Cross-check of Mali patch backports | Public; quoted briefly |
| Android `bionic` seccomp policy (android10-release) | Seccomp analysis | AOSP, Apache-2.0 |

## 5. Original content

Everything else — all prose, the QEMU lab scripts, the diagnostic methodology, the statistics, the build adaptations — was produced during this study and is licensed as described in [LICENSES.md](LICENSES.md).

## 6. Verification

`MANIFEST.sha256` lists the SHA-256 of every file in this repository. To verify a checkout:

```bash
sha256sum -c MANIFEST.sha256
```

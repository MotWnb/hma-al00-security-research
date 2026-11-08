# hme20-root-research

**Root feasibility study of a Huawei Mate 20 (HMA-AL00, Kirin 980) running HarmonyOS 4.0.0 — a fully documented negative result, plus a reproducible offline kernel lab.**

[中文说明](README.zh-CN.md) · [Device](DEVICE_INFO.md) · [Research](RESEARCH.md) · [Provenance](SOURCE_PROVENANCE.md) · [Audit](AUDIT_REPORT.md) · [Security policy](SECURITY.md)

---

## 1. What this is

This repository documents a multi-round, evidence-driven investigation into whether a **personally owned, fully updated** Huawei Mate 20 (HMA-AL00, Kirin 980) can be rooted **without disassembly**, using only software-reachable attack surface.

The short answer is **no**: no pure-software path to `uid=0` was found, and the one publicly demonstrated Kirin 980 bootloader-unlock primitive requires physical access (testpoint / BootROM USB). The long answer — which CVEs apply, which are dead ends and *why*, what the vendor hardened, and what a faithful offline reproduction of the most promising kernel bug looks like — is in [RESEARCH.md](RESEARCH.md).

> **This is not a root tool, and it does not contain one.**
> There is no exploit, no privilege-escalation payload and no flashing procedure in this repository. The most promising candidate, **CVE-2025-38352, was *not* successfully exploited on a real device** — the offline QEMU reproduction is recorded as `NOT_REPRODUCED` (5,500+ attempts, zero `WARN_ON_ONCE`, zero KASAN hits). Everything here is analysis, negative results, and a reproducible lab. If you are looking for a way to root this phone: there is currently no public software-only method, and this repository does not change that.

Every claim below carries one of these grades:

| Grade | Meaning |
|---|---|
| `SOURCE_CONFIRMED` | Verified line-by-line in the vendor's published kernel source. |
| `CONFIG_CONFIRMED` | Verified in the device's `/proc/config.gz` and/or the lab `.config`. |
| `ACCESS_CONFIRMED` | Verified on the real device that the code path is (or is not) reachable from an unprivileged context. |
| `REPRODUCED` | Observed at runtime, with logs. |
| `NOT_REPRODUCED` | Attempted under controlled conditions; not observed. |
| `INCONCLUSIVE` | Evidence insufficient; stated as such. |

Device data, QEMU data, diagnostic-kernel data and instrumented-kernel data are always labelled separately. **Code presence is never presented as successful exploitation**, and **temporary privilege escalation is never presented as full root**.

## 2. Device under study

| Item | Value |
|---|---|
| Model | HMA-AL00 (Huawei Mate 20) |
| SoC | Kirin 980 (`ro.boot.hardware=kirin980`, fastboot USB `VID_18D1/PID_D00D`, board "HI3650") |
| OS | HarmonyOS 4.0.0 (`hw_sc.build.platform.version=4.0.0`), EMUI 14.0.0, Android 10 / API 29 |
| Build | `HMA-AL00 10.1.0.163(C00E160R1P8)`, built 2024-01-31 |
| Kernel | Linux 4.14.116, built 2024-01-24, clang 9.0.3 |
| Security patch | Huawei 2024-02-01 (`ro.huawei.build.version.security_patch`) |
| Boot state | `ro.boot.flash.locked=1`, `verifiedbootstate=green`, `veritymode=enforcing`, `vbmeta.device_state=locked` |
| SELinux | Enforcing, `policyvers 310` |
| Disk | FBE (`ro.crypto.state=encrypted`, `type=file`) |

Full sanitized details: [DEVICE_INFO.md](DEVICE_INFO.md).

## 3. Main findings

### 3.1 Bootloader / root

| Route | Verdict | Evidence |
|---|---|---|
| Official unlock code | **Dead** — Huawei closed the service in 2018, before the Mate 20 shipped | Public record; `oem_unlock_supported=1` is only a capability flag |
| `fastboot oem unlock` on locked BL | **Rejected by design** | Locked `vbmeta`, `flash.locked=1`; no vendor fastboot unlock command documented |
| Testpoint / BootROM USB (Kirin-Tool) | **Works, but requires disassembly** — excluded by owner constraint | XDA guide for Kirin 710/970/980; BootROM exploit credited to TASZK; out of scope (no teardown) |
| Software testpoint (SWTP) | **Not applicable** — requires security patch ≤ 2021-01 | XDA guide scope; this device is 2024-02-01 |
| Downgrade → SWTP | **Blocked** — no signed downgrade path below the anti-rollback floor | Vendor rollback protection; no public counterexample on HarmonyOS 4.0.0 |
| KernelSU / APatch / Magisk | **Requires an already-unlocked bootloader** | `fastboot flash boot` is refused while locked |

### 3.2 Kernel and framework attack surface

| Candidate | Grade | Conclusion |
|---|---|---|
| `CONFIG_NAMESPACES` absent | `CONFIG_CONFIRMED` + `REPRODUCED` | `unshare -U/-Ur` → `EINVAL`; classic user-namespace privesc class is structurally impossible |
| Module loading | `CONFIG_CONFIRMED` | `MODULE_SIG_FORCE=y`, Huawei signing key; `modules_disabled` unreadable, `/system/lib/modules` absent |
| HWLOG ioctl family (`hwlog_exception`, `hwlog_dubai`, `hwlog_jank`) | `SOURCE_CONFIRMED` + `ACCESS_CONFIRMED` | 2022 TASZK bugs (`CVE-2022-22252`, `-22253`, `-22256`) are still present in code, but SELinux `allowxperm` whitelists and the removal of the dubai→zrhung dispatch make them **unreachable** from `shell`/`untrusted_app` |
| Mali Bifrost r18p0 kernel driver | `SOURCE_CONFIRMED` | Known CVEs (`CVE-2021-39793`, `CVE-2022-22706`, `CVE-2023-4211`, …) are **backported/fixed** in this tree |
| NPU (`/dev/davinci0`) | `CONFIG_CONFIRMED` | Not built (`NPU_CUT_MAKEFILE := yes`), no device node |
| `CVE-2026-43499` "GhostLock" (futex-PI) | `SOURCE_CONFIRMED` + `CONFIG_CONFIRMED` | Vulnerable code path present and gated open by default (`hw_futex_pi_enabled=0x1`), but exploitation needs stack-frame reclamation, an ARM64 CFI bypass and an HHEE bypass — **no memory-write demo, no root** |
| `CVE-2025-38352` (POSIX CPU timers / `sigqueue` UAF) | `SOURCE_CONFIRMED` + `CONFIG_CONFIRMED`; runtime **`NOT_REPRODUCED`** | The only candidate that is "code present + config on + reachable by an ordinary app"; offline QEMU reproduction did not hit the window in ~5,500 attempts |
| `CVE-2024-53104` (uvcvideo OOB write) | `SOURCE_CONFIRMED` | Fix absent, but requires a malicious USB video device **and** a camera-domain process; ordinary apps cannot open `/dev/video*` |
| `CVE-2025-1246` (Mali **userspace** driver OOB) | `CONFIG_CONFIRMED` (version match: r18p0-01rel0) | A userspace-driver bug; no kernel write primitive, therefore not a root path |
| HDB (`hdbd`) | `REPRODUCED` | Runs as `u:r:adbd:s0`, uid `shell(2000)` — same privilege as ADB, no root |
| Huawei framework CVEs (2023-52719, 2024-36500, 2024-56449, 2025-31170) | `INCONCLUSIVE` | Real Huawei PSIRT advisories, but **no public technical detail or PoC**; not usable as an entry point |

### 3.3 The one real kernel-lab result

`CVE-2025-38352` was reproduced **as an environment**, not as a UAF:

* Clean boot of the vendor's own 4.14.116 tree on QEMU ARM64 (`INIT_OK`, zero KASAN/panic warnings).
* A race trigger derived from the public `chronomaly` research, adapted to this kernel, ran **5,500+ iterations**: 2,332 timer fires, 1,531 "delete after reap" events, **0 `WARN_ON_ONCE` hits, 0 KASAN reports**.
* A diagnostic kernel proved the theoretical window exists: `run_posix_cpu_timers()` does process the firing list for `EXIT_ZOMBIE` tasks (`exit_state=32`, `fired=1`), 40/40 samples.
* Instrumented kernels (`mdelay` after `unlock_task_sighand()`, and a second variant inside the loop) also produced **0 hits**, because the delete-side thread is only woken *after* the loop has already fired the timer.

Verdict: `NOT_REPRODUCED`. The bug is real in this source tree; a faithful, reliable reproduction on this kernel/QEMU combination was **not** achieved, and the exploit prerequisites (KASLR leak, CFI bypass, HHEE `SELINUX_PROT` bypass) remain unproven. See [experiments/results/stage-a.md](experiments/results/stage-a.md).

## 4. What is *not* in this repository

Deliberately withheld (kept in a private archive, see [PRIVATE_ARCHIVE.md](PRIVATE_ARCHIVE.md)):

* Race-trigger source code and its precise timing parameters.
* Instrumented-kernel patches that widen the race window.
* Any KASLR leak technique or exploit offset for this device.
* Complete kernel-write / root exploit chains.
* Huawei proprietary binaries (APKs, `libGLES_mali.so`, `framework.jar`, the vendor source tarball itself).

If you are a Huawei PSIRT member and want the withheld material for coordinated disclosure, see [SECURITY.md](SECURITY.md).

## 5. Reproducing the offline lab

The lab uses the **vendor's own published GPL kernel source** (see [SOURCE_PROVENANCE.md](SOURCE_PROVENANCE.md)) on QEMU ARM64. It never touches a physical phone.

```bash
# Host: Ubuntu (WSL2 is fine), qemu-system-aarch64 >= 7, aarch64 GCC 9.x
git clone <this repo> && cd hme20-root-public
sudo apt-get install -y qemu-system-arm bc bison flex libssl-dev libelf-dev cpio make gcc
./qemu/README.md   # step-by-step: toolchain, config, build, initramfs, boot
```

Expected clean-boot output is in [logs/sanitized/boot-clean.excerpt.log](logs/sanitized/boot-clean.excerpt.log):

```
[    0.000000] Booting Linux on physical CPU 0x0000000000 [0x410fd083]
...
INIT_OK
```

The lab build required nine small adaptations to make the **vendor tree** compile and boot on QEMU (all documented in [patches/README.md](patches/README.md)); none of them touches `kernel/time/posix-cpu-timers.c`.

## 6. Repository layout

```
README.md / README.zh-CN.md   Overview (EN / ZH)
RESEARCH.md                   Full technical research, all rounds, with evidence grades
DEVICE_INFO.md                Sanitized device inventory and attack-surface map
SOURCE_PROVENANCE.md          Where the vendor source came from; SHA-256; licensing
KERNEL_CONFIG/                Device config excerpt + the exact lab .config
patches/                      Nine QEMU build adaptations (with rationale and license note)
qemu/                         Build & boot instructions, run script
security/cve/                 Per-CVE analysis (applicability, patch status, reachability)
security/selinux/             Policy excerpts and the ioctl-permission audit
experiments/results/          Stage A data: trigger statistics, diagnostic kernel, verdict
logs/sanitized/               Sanitized boot/diagnostic log excerpts
scripts/                      Helper scripts (config check, log scan, build summary)
LICENSES.md                   License inventory of every file group
CITATION.cff                  How to cite
SECURITY.md                   Disclosure contact and policy
AUDIT_REPORT.md               Sanitization + licensing audit of this release
PRIVATE_ARCHIVE.md            What was withheld, and why
MANIFEST.sha256               SHA-256 of every published file
```

## 7. Limits of this work

* **One device, one firmware.** `HMA-AL00 10.1.0.163(C00E160R1P8)`, HarmonyOS 4.0.0, patch 2024-02-01. Other builds may differ.
* **No disassembly.** The owner explicitly excluded teardown, which removes the only publicly demonstrated Kirin 980 unlock primitive.
* **No live exploitation.** Per the owner's safety constraint, no race/PoC was ever executed against the physical phone.
* **Not a claim of invulnerability.** A negative result for the tested attack surface is not proof that no bug exists.
* **QEMU ≠ device.** The lab kernel differs in nine source/build points, in the disabled subsystems and in `CONFIG_RANDOMIZE_BASE`; every lab statement is labelled accordingly.

## 8. Ethics and disclosure

Research was performed on a personally owned device, with read-only access unless explicitly stated. No device was bricked, no data was wiped, no partition was flashed. Vulnerabilities that appear to affect shipping Huawei firmware were **not** published with exploit detail; see [SECURITY.md](SECURITY.md) for the coordinated-disclosure position.

## 9. License

Documentation and original scripts: **CC BY 4.0** (text) / **MIT** (scripts), as stated in [LICENSES.md](LICENSES.md).
Kernel patches are derived from the vendor's GPL-2.0 kernel source and remain **GPL-2.0**; they are *not* relicensed. Vendor binaries are not distributed.

## 10. Contributing

Corrections are welcome and are the main reason this is public.

* **Factual errors** (wrong line number, mis-attributed CVE, broken step): open an issue with the file, the claim, and the evidence that contradicts it.
* **Reproduction attempts**: if you can get CVE-2025-38352 to produce a `WARN_ON_ONCE` or a KASAN report on a real 4.14.116 build, that is the single most valuable contribution — please describe the method, not a weaponised payload.
* **Hardware data points**: the same firmware on a different Kirin 980 device, or a different patch level, is useful for the applicability table.
* **Licensing/attribution**: tell us if something is credited incorrectly.

Please keep pull requests to documentation and analysis. **Do not submit exploit code, trigger sources, or KASLR/offset material** — such PRs will be closed, and the material should go through the private channel in [SECURITY.md](SECURITY.md). By contributing you agree that text/scripts are licensed as described in [LICENSES.md](LICENSES.md).

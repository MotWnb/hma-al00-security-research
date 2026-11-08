# security/cve — per-CVE analysis

Each document follows the same structure:

1. **What the bug is** (upstream description, fixing commit).
2. **Is the vulnerable code in this exact tree?** (`SOURCE_CONFIRMED` line references).
3. **Is the relevant config on?** (`CONFIG_CONFIRMED`).
4. **Is it reachable from an unprivileged context on this device?** (`ACCESS_CONFIRMED` or reasoned).
5. **What would exploitation require that we have not demonstrated?**
6. **Verdict**, using the four stages: *code present → trigger conditions met → memory-write primitive → uid 0*.

| Document | Subject | Verdict summary |
|---|---|---|
| [CVE-2025-38352.md](CVE-2025-38352.md) | POSIX CPU timers `sigqueue` UAF | code+config+access yes; **not reproduced**; no write primitive shown |
| [CVE-2026-43499.md](CVE-2026-43499.md) | futex-PI / rtmutex "GhostLock" | code+config yes; gate open by default; no ARM64 chain; no root |
| [CVE-2024-53104.md](CVE-2024-53104.md) | uvcvideo out-of-bounds write | code present, fix absent; needs physical USB + camera domain |
| [CVE-2025-1246.md](CVE-2025-1246.md) | Mali Bifrost **userspace** OOB | version matches; userspace-only, not a root path |
| [CVE-2022-22252-56.md](CVE-2022-22252-56.md) | hwlog / zrhung / memcheck | code present; **SELinux-unreachable** |
| [huawei-framework-cves.md](huawei-framework-cves.md) | 4 framework CVEs | advisories only — `INCONCLUSIVE` |

A note on method: kernel version ranges are **not** used as evidence. Every judgment is made against the vendored source at `Code_Opensource/kernel/`, because Huawei backports selectively and the published version string says nothing about which fixes are present.

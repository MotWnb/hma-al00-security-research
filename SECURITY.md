# Security policy and coordinated disclosure

## Scope

This repository documents research on a **single, personally owned** Huawei Mate 20 (HMA-AL00), performed with read-only ADB access and an offline QEMU lab. It is published as a negative result and a methodology reference.

## What is deliberately *not* published

To avoid shipping a working exploit for firmware that is still in the field, the following are withheld (see [PRIVATE_ARCHIVE.md](PRIVATE_ARCHIVE.md)):

* race-trigger source code and its precise timing parameters;
* instrumented-kernel patches that widen the race window;
* KASLR disclosure techniques and exploit offsets for this device;
* any complete kernel-write or root chain.

What *is* published — source line numbers, config symbols, SELinux rules, and negative results — is enough to reproduce the *analysis*, not the *exploitation*.

## How to report — choose the right channel

### A. A problem with *this repository* (documentation error, broken script, licensing, accidental data)

Open a normal GitHub issue. Use the issue templates:

* **Bug / factual error** — wrong line number, mis-attributed CVE, broken reproduction step.
* **Licensing or attribution** — missing credit, license conflict.
* **Data exposure** — an identifier that should have been redacted.

These are not product vulnerabilities and should not be sent to a vendor.

### B. A security vulnerability in a **Huawei product** (including this device's firmware)

**Do not open a public issue in this repository.** This project is not a vendor, cannot issue fixes, and publishing details here could put users at risk.

Report it to Huawei PSIRT through the official channel:

* **Email:** `psirt@huawei.com`
* **Web form / reporting instructions:** <https://www.huawei.com/en/psirt/report-vulnerabilities/>

The Huawei PSIRT page also documents their PGP key and the information they need (affected product and version, reproduction steps, impact, and any proposed disclosure timeline). Include the firmware build string (`HMA-AL00 10.1.0.163(C00E160R1P8)`) and the kernel version (`4.14.116`, build 2024-01-24) when relevant — both are published in [DEVICE_INFO.md](DEVICE_INFO.md), so no private data is needed.

### C. You are a vendor or CERT and want the withheld material

If you represent Huawei PSIRT, Honor, or a national CERT and want the withheld trigger/timing material for triage or coordinated disclosure, open an issue **without technical detail** stating your affiliation and a contact channel. Access will be arranged privately, under an explicit agreement.

Relevant open items, in the order we would triage them:

1. **CVE-2025-38352** (POSIX CPU timers) — vulnerable code confirmed present in `HMA-AL00 10.1.0.163(C00E160R1P8)` kernel sources (2024-01-24); offline reproduction unsuccessful, so real-world exploitability on this build is **unknown**.
2. **CVE-2026-43499** (GhostLock / futex-PI) — vulnerable code confirmed present; the vendor gate `hw_futex_pi_enabled` defaults to `0x1`, which leaves the vulnerable `FULL_CHAINWALK` path active.
3. **CVE-2024-53104** (uvcvideo) — fix absent from this tree; requires physical USB access plus a camera-domain process.
4. **CVE-2022-22252 / -22256 / -22253** (HWLOG) — root-cause code unchanged in 2024 sources; mitigated only by SELinux `allowxperm` policy. This is a policy mitigation, not a code fix, and is worth a vendor review.
5. Nine build-level vendor defects documented in [patches/README.md](patches/README.md) (not security issues, but they break the published tree on non-Huawei platforms).

## Reporting a problem with this repository

Open a GitHub issue for: factual errors, wrong line numbers, mis-attributed CVEs, license problems, or accidental disclosure of sensitive data. For anything that looks like an undisclosed vulnerability in shipping firmware, do **not** open a public issue — use the vendor channel above.

## Our commitments

* We will not publish exploit code for unfixed vendor vulnerabilities.
* We will correct any factual error promptly and note the correction in the commit message.
* Device identifiers were removed before publication; if you find one, report it and it will be removed and the history rewritten.

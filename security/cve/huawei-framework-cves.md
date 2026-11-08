# Huawei framework CVEs — advisories without primitives

**Grade: `INCONCLUSIVE`. Not usable as an entry point.**

## 1. The four CVEs

| CVE | Huawei description | CWE | CVSS | Affected (as listed) | Fixed in bulletin |
|---|---|---|---|---|---|
| CVE-2025-31170 | "Access control vulnerability in the security verification module" | CWE-290 | 8.4 (Huawei) / 9.1 (NVD) | HarmonyOS 4.0.0 / 4.3.0 / 5.0.0, EMUI 14.0.0 | 2025-04 |
| CVE-2024-56449 | "Privilege escalation vulnerability in the Account module" | CWE-840 | 6.6 | HarmonyOS 2.0–4.2, EMUI 12/13/14 | 2025-01 |
| CVE-2024-36500 | "Privilege escalation vulnerability in the AMS module" | CWE-269 | 7.8 | HarmonyOS 3.0/3.1/4.0/4.2, EMUI 13/14 | 2024-06 |
| CVE-2023-52719 | "Privilege escalation vulnerability in the PMS module" | CWE-16 | 7.1 | HarmonyOS 2.0–4.0.0, EMUI 12/13/14 | 2024-05 |

All four name HarmonyOS 4.0.0 explicitly, and all four were fixed **after** this device's 2024-02-01 patch level — so the vulnerable versions are probably present. That is the only thing that can be said with confidence.

## 2. What is missing

* No technical description beyond the one-line Huawei PSIRT text.
* No PoC, no exploit, no root primitive described.
* GitHub code search for each CVE ID returns 0 repositories.
* EPSS ≈ 0.001, CISA SSVC exploitation = none.
* The affected code lives in vendor framework JARs that are **stubs** on this device (`services.jar` is 183 bytes); the real implementations are in `oat/arm64/*.odex` + `vdex`, which were not decompiled.

## 3. Why they are not a route

A framework privilege escalation that yields `system`/`radio` is not root. Turning it into root requires a *second*, kernel-level primitive — and the kernel surface on this device is separately documented as unreachable ([../README.md](../README.md), [CVE-2022-22252-56.md](CVE-2022-22252-56.md), [CVE-2025-38352.md](CVE-2025-38352.md)).

They are recorded as **open questions**: if a write-up appears, the vdex extraction described in [../../DEVICE_INFO.md](../../DEVICE_INFO.md) §10 is the next step.

## 4. Verdict

| Stage | Result |
|---|---|
| Code present | **unknown** (framework code not decompiled) |
| Exploitable | **unknown** — no public detail |
| Root relevance | **unknown**, likely indirect |

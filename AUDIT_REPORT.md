# Audit report — sanitization, licensing, and content review

Audit performed: 2026-11-08, before any publication. Scope: every file in this release candidate.

## 1. Sanitization

### 1.1 Identifiers

| Identifier class | Status | Action |
|---|---|---|
| Device serial number | Found in working notes only | Not copied into `hme20-root-public/`; independently scanned the release tree afterwards (0 hits) |
| IMEI / MEID | Never collected in full | Not present |
| MAC addresses | Only Wi-Fi/BT interface names in getprop, no values | Not present |
| Android ID / `boot_id` | `boot_id` was read once for a lab note | Not published |
| Google account / Huawei ID | Never collected | Not present |
| ADB RSA key fingerprints | Not collected | Not present |

### 1.2 Host and path information

| Item | Status |
|---|---|
| Windows user profile path (`C:\Users\…)` | Not present in the release tree |
| Desktop hostname in the kernel banner (`root@DESKTOP-…`) | Replaced with `<host>` in `logs/sanitized/boot-clean.excerpt.log` |
| WSL private paths (`D:\wsl\…`) | Replaced with the neutral "private archive" wording |
| Lab paths (`/opt/lab/...`) | **Kept** — they document the reproducible environment and contain no personal data |
| Network addresses / proxy settings | Not present |

### 1.3 Kernel and exploit-sensitive data

| Item | Status |
|---|---|
| Kernel symbol addresses / offsets | Not present in published logs (lab has `RANDOMIZE_BASE=n`, and excerpts contain no addresses) |
| Race timing parameters | Withheld (`PRIVATE_ARCHIVE.md`) |
| Trigger source | Withheld |
| KASLR leak details | Withheld; only "common surfaces are closed" is public |
| Full raw logs | Withheld; excerpts only |

### 1.4 How the scan was done

```
grep -RIn --binary-files=without-match -e '<device-serial>' -e 'IMEI' -e 'DESKTOP-' \
     -e 'C:\\Users' -e 'D:\\wsl' -e 'boot_id' -e '86138' .
```

Expected result after the fixes above: **0 hits** (the strings themselves appear only in this audit document, which is intentional and contains no values).

## 2. Licensing review

| Group | Decision |
|---|---|
| Original prose | CC BY 4.0 — clean |
| Original scripts | MIT — clean |
| `patches/*.patch` | Derived from vendor GPL-2.0 source; kept GPL-2.0; attribution via `SOURCE_PROVENANCE.md` — clean |
| `KERNEL_CONFIG/lab-config…` | Config of a GPL-2.0 work; distributed with the work — clean |
| Vendor binaries | **Excluded**; only SHA-256 published — clean (no redistribution) |
| Vendor source tarball | **Excluded**; URL + SHA-256 only — GPL compliance via the vendor's own download |
| SELinux CIL | Excerpts only, for factual claim support — kept minimal |
| Third-party research | Referenced and briefly quoted with attribution; no code copied |

Uncertain items isolated rather than published: none remained at the end of the review. (Earlier drafts included `trigger.c` and `widen-window.patch`; both were moved to the private archive.)

## 3. Content review — claims vs evidence

Every quantitative claim in `README.md`, `RESEARCH.md` and `experiments/results/stage-a.md` was cross-checked against a log or a source line:

| Claim | Evidence | Verified |
|---|---|---|
| `INIT_OK`, 0 KASAN/panic | `logs/sanitized/boot-clean.excerpt.log`; full log hash in private archive | yes |
| 5,300 / 5,600 tries, 2,847 / 2,332 fires, 1,000 / 1,531 wins, 0 hits | trigger SUMMARY lines; `experiments/results/stage-a.json` | yes |
| `spins=0`, `attempts=952 ok=952` | `STATS` line in diag log | yes |
| 40/40 `run-exiting` with `exit_state=32 fired=1` | `diag-run1.excerpt.log` | yes |
| Source line numbers (`posix-cpu-timers.c`, `rtmutex.c`, etc.) | re-read in the vendor tree | yes |
| `CONFIG_NAMESPACES` absent; `unshare` → EINVAL | device config + runtime output in `RESEARCH.md` §3 | yes |
| ioctl return codes per device | probe run output in `security/cve/CVE-2022-22252-56.md` | yes |
| Mali version `r18p0-01rel0` | strings in `libGLES_mali.so` (hash published) | yes |

No claim was found to overstate the result: the QEMU work is labelled `NOT_REPRODUCED` throughout, and no "root achieved" claim exists anywhere.

## 4. Structure and reproducibility check

* Every directory referenced from `README.md` exists.
* `patches/` contains exactly the nine patches described; `qemu/README.md` lists them in apply order.
* `experiments/results/stage-a.json` parses as valid JSON.
* `MANIFEST.sha256` covers every published file (generated last).
* The QEMU instructions were executed end-to-end during the study (the published logs come from them).

## 5. Open items for the human reviewer

1. **Repository URL** in `CITATION.cff` is a placeholder (`example.invalid`) — replace before publishing.
2. **Contributor identity**: `CITATION.cff` uses a generic author; add a name/handle if desired.
3. **Vendor contact**: `SECURITY.md` describes the channel but does not name a PSIRT address; add one if known.
4. **Withheld material custody**: confirm where the private archive should live long-term.
5. **Firmware support status**: confirm whether `10.1.0.163` is still receiving updates before deciding whether to ever publish the trigger.

## 6. Verdict

**Ready to publish as a release candidate**, subject to reviewer decisions in §5. No sensitive identifiers, no proprietary binaries, no exploit code, and no relicensed GPL material were found in the release tree.

---

## 7. Publication-time re-audit (2026-11-08, staging copy)

The release was re-audited in a clean staging copy (`D:\release\hma-al00-security-research`) before `git init`, so the original candidate directory was never modified by publication steps.

| Check | Tool / method | Result |
|---|---|---|
| Secret scanning (working tree) | **gitleaks 8.30.1**, `gitleaks dir --redact -v` | **0 leaks** |
| Secret scanning (git history) | gitleaks `git` mode after the initial commit | see publication log |
| Identifier regex (serial, hostname, `C:\Users`, `D:\wsl`) | PowerShell `Select-String` over all files | 0 real hits (only the words "IMEI"/"boot_id" in explanatory prose) |
| Binary content | NUL-byte scan of every file | 0 binaries |
| Large files (>1 MB) | size scan | none (largest: `KERNEL_CONFIG/lab-config…`, 105 KB) |
| Hidden files / reparse points | attribute scan | none |
| Manifest integrity | SHA-256 of every file vs `MANIFEST.sha256` | 46/46 matched before edits; regenerated to **50/50** after metadata additions |
| Private material exclusion | path scan for `trigger*.c`, `widen-window.patch`, `*.orig`, `*.log` | none present (`.gitignore` also blocks them) |
| License review | per-group table in `LICENSES.md` | no blanket license applied; GPL-2.0 derivatives kept GPL-2.0 |

TruffleHog was requested but is **not installed** on this machine; gitleaks was installed from its official GitHub release (`v8.30.1`) and used instead. No scan result is claimed that was not actually produced by a tool.

### Post-audit metadata changes

* `CITATION.cff` — author `MotWnb`, repository URL filled in, version `1.0.0`.
* `SECURITY.md` — formal Huawei PSIRT channel (`psirt@huawei.com`, PSIRT web form) and a clear split between project issues and product vulnerabilities.
* `README.md` / `README.zh-CN.md` — explicit "this is not a root tool" disclaimer and a contributing section.
* `LICENSES.md` — explanation of why no single `LICENSE` file exists.
* `.gitignore`, `.github/ISSUE_TEMPLATE/*` — repository hygiene; issue templates route product vulnerabilities to Huawei PSIRT.

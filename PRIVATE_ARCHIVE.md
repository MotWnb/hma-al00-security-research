# Private archive — what was withheld, and why

The public repository contains the *analysis*. The following material is kept **outside** the repository (on the research machine, outside this repository) and is not committed, not packaged, and not uploaded.

| Item | Files | Why withheld |
|---|---|---|
| Race trigger (v1) | `trigger.c`, `Makefile` | Working choreography for a UAF against unfixed firmware; timing knobs are the hard part. |
| Race trigger (v2) | `trigger-v2.c` | Same, with busy-poll wake-up and statistics. |
| Instrumented kernel | `widen-window.patch` and variants | Turns the race into a deterministic crash; a recipe for weaponisation. |
| Diagnostic probes | patch + logs | Function-offset and window data useful for exploitation; the *conclusion* is public, the offsets are not. |
| Raw QEMU logs | `boot-trig.log` (75 KB), `diag-run1.log` (71 KB), `widen*.log` | Contain symbol offsets, timing distributions and probe output. Sanitised excerpts are published. |
| KASLR notes | device probing results and candidate leak surfaces | Directly actionable for a future chain; only the high-level finding ("common leak surfaces are closed") is public. |
| Full device config | 6,754 lines | Only 95 relevant symbols published; the rest is noise with occasional build fingerprints. |
| Vendor binaries | APKs, `libGLES_mali.so`, `framework.jar`, `libc.so`, SELinux CIL files | Copyright; hashes published instead. |
| Vendor source tarball | 592 MB gzip | Size + GPL compliance via Huawei's own URL; hash published. |

## Handling rules

1. The private archive never lives inside the repository working tree (no `.gitignore` reliance).
2. If this material is ever shared, it goes to the vendor/CERT channel described in [SECURITY.md](SECURITY.md), under an explicit agreement.
3. Before any future publication of exploitation material, the affected firmware must be out of support or the vendor must have shipped a fix.

## Relationship to the public release

Public claims do not depend on withheld material for their *validity* — only for their *reproduction as an exploit*. Every withheld item is referenced by a published conclusion, with the relevant line numbers and statistics in [experiments/results/stage-a.md](experiments/results/stage-a.md) and [security/cve/](security/cve/).


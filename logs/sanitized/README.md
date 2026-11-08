# logs/sanitized

Two excerpts, both from the **offline QEMU lab**:

| File | Source | What it proves |
|---|---|---|
| `boot-clean.excerpt.log` | `/opt/lab/logs/boot-clean.log` (10,355 B) | The vendor 4.14.116 tree, with the nine adaptations, boots to `INIT_OK` with zero KASAN/panic/warning output on QEMU ARM64. |
| `diag-run1.excerpt.log` | `/opt/lab/logs/diag-run1.log` (71,428 B) | The diagnostic kernel observed a non-empty firing list on `EXIT_ZOMBIE` tasks (the race window exists), while the deleter always found the list empty. |

## Sanitization applied

* Device serial, IMEI, MAC, Android ID and `boot_id`: not present in the sources; independently scanned for and absent.
* Host/desktop name in the kernel banner: replaced with `<host>` (build-time string).
* Local user names and private paths: not present in the lab logs; lab paths (`/opt/lab/...`) are retained because they document the environment.
* Kernel addresses: the lab runs with `CONFIG_RANDOMIZE_BASE=n` and the excerpts contain no symbol addresses; full logs remain private because they contain function offsets useful for exploitation.

## What is withheld

Raw logs (75 KB boot-with-trigger log, 71 KB diagnostic log, instrumented-kernel logs) are kept in the private archive. They contain trigger timing, function offsets and probe details that fall under the exclusion policy in [../PRIVATE_ARCHIVE.md](../PRIVATE_ARCHIVE.md).

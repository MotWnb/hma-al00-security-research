# scripts/

Small, dependency-free helpers used during the study. They are published because they make the claims checkable; none of them exploits anything.

| Script | Purpose | Usage |
|---|---|---|
| `check-cfg.sh` | Assert that a built `.config` has the symbols the experiment depends on and lacks the ones that break QEMU. Exits non-zero on mismatch. | `./check-cfg.sh /opt/lab/build/.config` |
| `scan-log.sh` | Scan a QEMU serial log for kernel version, KASAN reports, the `posix_cpu_timer_del` WARN, UAF mentions and trigger markers; prints a summary. | `./scan-log.sh /opt/lab/logs/diag-run1.log` |
| `boot-probe.sh` | Boot a kernel + initramfs, capture the log, print the tail. | `./boot-probe.sh <Image> <initramfs> <logname>` |
| `boot-smc.sh` | Boot variant that tests the PSCI-conduit failure (documented in `patches/README.md`). | `./boot-smc.sh` |
| `latest-logs.sh` | List the newest lab logs by mtime. | `./latest-logs.sh` |
| `summarize-patches.sh` | List applied patches with line counts. | `./summarize-patches.sh /opt/lab/logs` |

The QEMU wrapper itself is in [`../qemu/run-qemu.sh`](../qemu/run-qemu.sh).

## License

MIT (see [../LICENSES.md](../LICENSES.md)).

## Note

The scripts assume the lab layout described in [`../qemu/README.md`](../qemu/README.md): kernel tree in `/opt/lab/kernel`, build dir in `/opt/lab/build`, logs in `/opt/lab/logs`. Adjust the paths at the top if yours differ.

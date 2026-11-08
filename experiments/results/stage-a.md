# Stage A — offline reproduction of CVE-2025-38352

**Verdict: `NOT_REPRODUCED`.** The vulnerable code is present and the theoretical window is real, but no UAF was observed in the isolated lab.

All data here is **QEMU ARM64**, not the physical device. The physical device was never used for race testing.

## 1. Environment

| Item | Value |
|---|---|
| Kernel tree | vendor `HMA-AL00-TL00_HarmonyOS4.0.0`, `Code_Opensource/kernel`, 4.14.116 |
| Kernel build | `#8 SMP PREEMPT`, 2026-11-08, GCC 9.2.1 aarch64 |
| Image size | 26,374,656 B |
| Machine | `qemu-system-aarch64 -M virt -cpu cortex-a72 -smp 4 -m 3072` |
| QEMU | 10.2.1 |
| Config | [lab-config-arm64-4.14.116](../KERNEL_CONFIG/lab-config-arm64-4.14.116) (KASAN, `HZ=1000`, `PREEMPT`, `RANDOMIZE_BASE` off) |
| Boot marker | `INIT_OK`, zero `BUG: KASAN` / `panic` / `WARNING` |
| Build adaptations | 9, see [patches/README.md](../patches/README.md); timer code untouched |

Boot log excerpt: [logs/sanitized/boot-clean.excerpt.log](../logs/sanitized/boot-clean.excerpt.log).

## 2. Trigger design

Derived from the public `chronomaly` choreography (x86_64 5.10), reimplemented for this kernel:

* **Racer**: arms one `CLOCK_THREAD_CPUTIME_ID` timer (SIGEV_SIGNAL/SIGUSR1) plus 18 stall timers, so the firing list fills up to the `check_timers_list()` cap of 19–20 per tick; burns CPU with `getpid()` until just before expiry, then returns → `do_exit()`.
* **Free thread**: catches SIGUSR1 via `signalfd` and calls `timer_delete()` on the racer's timer.
* **Parent**: `ptrace(PTRACE_ATTACH)` the racer (keeps it `EXIT_ZOMBIE`), then `waitpid()` → `release_task()` → `__exit_signal()` → `sighand = NULL`, concurrently with the IRQ.

The trigger source and its timing parameters are **deliberately not published** (see [PRIVATE_ARCHIVE.md](../PRIVATE_ARCHIVE.md)); the published data is sufficient to reproduce the *method*, not the tuned artifact.

## 3. Lab vs device differences (must be read with every result)

| Difference | Device | Lab | Effect |
|---|---|---|---|
| `CONFIG_RANDOMIZE_BASE` | on | off (debuggability) | lab addresses stable; KASLR effects untested |
| THP | off | off (vendor arm64 tree lacks THP primitives) | same as device |
| Disabled subsystems | many enabled | PCI/MTD/I2C/SPI/DRM/FB/MMC/SND/MEDIA/SMMU off | more free memory, different allocator pressure |
| `SERIAL_8250` | on | off | avoids an unrelated 4.14 serdev KASAN report at boot |
| `GPIO_PL061`/keys | on | off | avoids a vendor spinlock `BUG_ON` on QEMU DT |
| `cpu_errata.c` PSCI conduit | vendor hard-codes SMC | upstream switch restored | QEMU has no EL3 |
| 8 other source/build points | — | see patches | no timer/futex/scheduler semantics changed |
| Timing | real hardware, 8 cores, big.LITTLE | TCG, 4 vCPU | interrupt/notify latency differs by 1–2 orders of magnitude |

Everything in §4 is therefore **lab-only** evidence.

## 4. Results

### 4.1 Race counters

| Run | Configuration | Tries | Fires | delete-after-reap | `WARN_ON_ONCE` | KASAN |
|---|---|---|---|---|---|---|
| v1 short | blocking `poll` wake, 18 stall timers | 1,100 | 612 | 186 | 0 | 0 |
| v1 long | same, 300 s cap | 5,300 | 2,847 | 1,000 | 0 | 0 |
| v2 | `SFD_NONBLOCK` busy poll, `MARGIN_NS=60000` | 5,600 | 2,332 | 1,531 | 0 | 0 |
| v2 (60 s, stats printed) | same | 2,367 | 952 | 295 | 0 | 0 |

`v2` full statistics:

```
SUMMARY tries=2367 fires=952 deletes=952 won=295 hits=0 timeout
STATS attempts=952 ok=952 einval=0 spins=0
HIST ok_delta_us 0-5=947
```

`spins=0` is the key number: **not once** did `timer_delete()` hit the `TIMER_RETRY` path, i.e. the timer was never on the firing list at deletion time. "won" only means "the delete happened after the reap" — by then the IRQ had already `list_del_init()`-ed the entry.

### 4.2 Diagnostic kernel (proves the window exists)

Three temporary `pr_warn()` probes (rolled back; `strings Image | grep -c PCBDBG` = 0 in the published image):

| Probe | Location | Observation |
|---|---|---|
| `del-null` | `posix_cpu_timer_del()`, `sighand == NULL` branch | 40/40: `entry_empty=1 firing=0` |
| `run-nosighand` | `lock_task_sighand()` failure return | 38 samples, `exit_state=16` (`EXIT_DEAD`) |
| `run-exiting` | after `unlock_task_sighand()`, only when `tsk->exit_state != 0` | 40/40: `exit_state=32` (`EXIT_ZOMBIE`), `fired=1` |

Conclusion: a zombie's tick **does** process a non-empty firing list — the window is real. But when the deleter obtains `sighand == NULL`, the list is already empty, so the `WARN_ON_ONCE` at `posix-cpu-timers.c:389` never fires.

Excerpt: [logs/sanitized/diag-run1.excerpt.log](../logs/sanitized/diag-run1.excerpt.log).

### 4.3 Instrumented kernels (widening the window)

| Variant | Insertion point | Result |
|---|---|---|
| widen 20 ms | after `unlock_task_sighand()`, before the loop | 0 WARN, 0 KASAN |
| widen 50 ms | same | 0 WARN, 0 KASAN |
| widen-v2 50 ms | inside the loop, after the first `cpu_timer_fire()` | 0 WARN, `attempts=685 ok=685 einval=0 spins=0` |

Why the first two failed: the free thread is woken by `send_sigqueue()` **inside** `cpu_timer_fire()`, which runs after the delay — the deleter is not running yet. The third variant wakes it but the delete still completes after the loop has emptied the list.

These variants are labelled "artificially widened window" and are **not** evidence of a natural hit rate. The patches are withheld.

## 5. Interpretation

The bug is real in this source tree (`SOURCE_CONFIRMED`), the config does not disable it (`CONFIG_CONFIRMED`), and the syscall path is reachable (`ACCESS_CONFIRMED`). What was not achieved is the scheduling coincidence that makes `posix_cpu_timer_del()` observe `firing=1` while `sighand == NULL`.

Winning requires the tick to land **after `exit_notify()` and before `release_task()` completes**, with the deleter already inside the driver. Under TCG the wake-up latency difference between the two threads is ~0.5–1.2 ms, three orders of magnitude larger than the window. This may be a QEMU artifact — or it may reflect the difficulty of the real target as well. Either way, `NOT_REPRODUCED`.

## 6. What would move this forward

1. Hardware-assisted reproduction (KVM on an ARM64 host, or a physical test device) to get realistic interrupt latency.
2. A different signalling strategy that does not depend on `send_sigqueue()` for wake-up (e.g. a second thread already spinning in the delete path, with `futex`-based release).
3. A `SLAB_MERGE_DEFAULT=n` configuration closer to the reference exploit, so that a successful free is observable via cross-cache effects.

None of these was executed; all would happen in the isolated lab, never on the phone.

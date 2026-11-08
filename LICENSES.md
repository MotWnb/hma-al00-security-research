# License inventory

## Why there is no single `LICENSE` file

This repository deliberately mixes licenses because it mixes kinds of work: original prose, original scripts, and patches derived from GPL-2.0 kernel code. Applying one license to everything would either mislicense the GPL-2.0 derivatives or over-restrict the original text. Each group is therefore licensed separately below. If you need one machine-readable identifier for citation purposes, use **CC-BY-4.0** for the documentation and **MIT** for the scripts, and **GPL-2.0** for `patches/`.

This repository mixes original work with material derived from GPL-2.0 kernel sources. Each group is licensed as follows; nothing is relicensed across groups.

| Path | Content | License | Basis |
|---|---|---|---|
| `README.md`, `README.zh-CN.md` | Original prose | **CC BY 4.0** | Original work |
| `RESEARCH.md`, `DEVICE_INFO.md`, `SOURCE_PROVENANCE.md` | Original prose | **CC BY 4.0** | Original work |
| `security/**` (analysis text) | Original prose | **CC BY 4.0** | Original work |
| `experiments/results/**` | Original data + prose | **CC BY 4.0** | Original work |
| `logs/sanitized/**` | Excerpts of logs produced in this study | **CC BY 4.0** | Original work (excerpts of our own captures) |
| `scripts/*.sh`, `qemu/run-qemu.sh` | Original scripts | **MIT** | Original work |
| `patches/*.patch` | Diffs against vendor GPL-2.0 kernel source | **GPL-2.0** | Derivative of GPL-2.0 code; **not** relicensed |
| `KERNEL_CONFIG/lab-config-arm64-4.14.116` | Kernel configuration | **GPL-2.0** | Configuration of a GPL-2.0 work; distributed as part of the same work |
| `KERNEL_CONFIG/device-config-relevant.txt` | 95 config symbols from the device | **CC BY 4.0** (facts) | Configuration symbol names/values are functional facts |

## Not distributed at all

| Item | Reason |
|---|---|
| Vendor kernel tarball (`HMA-AL00-TL00_HormonyOS4.0.0_opensource.tar.gz`, 592 MB) | GPL-2.0, but 592 MB; Huawei's own download page satisfies compliance. URL and SHA-256 are published in `SOURCE_PROVENANCE.md`. |
| Huawei APKs, `libGLES_mali.so`, `framework.jar`, `libc.so` | Proprietary, no redistribution right. Hashes published so claims are checkable. |
| `plat_sepolicy.cil`, `vendor_sepolicy.cil`, `plat_pub_versioned.cil` (full) | Large compiled policy artifacts; only decision-relevant excerpts published. |
| Race trigger sources, instrumented-kernel patches, timing parameters, KASLR notes | Safety policy, see `PRIVATE_ARCHIVE.md`. |

## Text of the licenses

* **CC BY 4.0** — <https://creativecommons.org/licenses/by/4.0/legalcode>
* **MIT** — see below.
* **GPL-2.0** — <https://www.gnu.org/licenses/old-licenses/gpl-2.0.html>

### MIT (for original scripts)

```
Copyright (c) 2026 hme20-root-research contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Third-party references (not vendored)

TASZK Security Labs write-ups, Google Project Zero RCAs, `farazsth98/chronomaly`, and AOSP `bionic` sources are **referenced** and briefly quoted for technical cross-checking; no code is copied. Their own licenses govern them.

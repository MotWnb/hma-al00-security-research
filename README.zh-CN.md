# hme20-root-research

**华为 Mate 20（HMA-AL00，麒麟 980 / HarmonyOS 4.0.0）Root 可行性研究——一份完整记录的负面结果，以及一套可复现的离线内核实验环境。**

[English](README.md) · [设备档案](DEVICE_INFO.md) · [技术研究](RESEARCH.md) · [来源与许可](SOURCE_PROVENANCE.md) · [审计报告](AUDIT_REPORT.md)

---

## 1. 这是什么

本仓库记录了对一台**个人所有、已更新到最新**的华为 Mate 20（HMA-AL00，麒麟 980）进行的多轮 Root 可行性研究：目标是在**不拆机**的前提下，仅通过软件可达的攻击面取得 `uid=0`。

结论是**否定的**：没有找到任何纯软件 Root 路径；公开可证的麒麟 980 Bootloader 解锁手段（测试点 / BootROM USB）需要物理接触。至于"哪些 CVE 适用、哪些是死路以及**为什么**、厂商加固了什么、最有希望的内核漏洞在离线环境里到底长什么样"，见 [RESEARCH.md](RESEARCH.md)。

> **这不是一个 Root 工具，也不包含 Root 工具。**
> 仓库里没有利用代码、没有提权载荷、没有刷机步骤。最有希望的候选 **CVE-2025-38352 并未在真机上利用成功**——离线 QEMU 复现记录为 `NOT_REPRODUCED`（5500+ 次尝试、0 次 `WARN_ON_ONCE`、0 次 KASAN）。这里只有分析、负面结果和可复现的实验环境。如果你在找这台手机的 Root 方法：目前没有公开的纯软件方案，本仓库也没有改变这一点。

全文证据分级：

| 等级 | 含义 |
|---|---|
| `SOURCE_CONFIRMED` | 在厂商公开的内核源码中逐行核对确认 |
| `CONFIG_CONFIRMED` | 在设备 `/proc/config.gz` 和/或实验 `.config` 中确认 |
| `ACCESS_CONFIRMED` | 在真机上确认该代码路径对非特权上下文可达 / 不可达 |
| `REPRODUCED` | 运行时实际观测到，并有日志 |
| `NOT_REPRODUCED` | 在受控条件下尝试过，未观测到 |
| `INCONCLUSIVE` | 证据不足，明确标注 |

真机数据、QEMU 数据、诊断内核数据、插桩内核数据**始终分开标注**。**代码存在 ≠ 利用成功**；**临时提权 ≠ 完整 Root**。

## 2. 研究对象

| 项目 | 值 |
|---|---|
| 型号 | HMA-AL00（华为 Mate 20） |
| SoC | 麒麟 980（`ro.boot.hardware=kirin980`，fastboot USB `VID_18D1/PID_D00D`） |
| 系统 | HarmonyOS 4.0.0（`hw_sc.build.platform.version=4.0.0`），EMUI 14.0.0，Android 10 / API 29 |
| 版本 | `HMA-AL00 10.1.0.163(C00E160R1P8)`，构建于 2024-01-31 |
| 内核 | Linux 4.14.116，构建于 2024-01-24 |
| 安全补丁 | 华为 2024-02-01 |
| 启动状态 | `ro.boot.flash.locked=1`、`verifiedbootstate=green`、`veritymode=enforcing` |
| SELinux | Enforcing，`policyvers 310` |
| 存储 | FBE 文件级加密 |

完整脱敏信息见 [DEVICE_INFO.md](DEVICE_INFO.md)。

## 3. 主要结论

### 3.1 Bootloader / Root

| 路线 | 判定 | 依据 |
|---|---|---|
| 官方解锁码 | **已死**（华为 2018 年关闭服务，早于 Mate 20 上市） | 公开记录 |
| 锁定 BL 上 `fastboot oem unlock` | **设计上拒绝** | `vbmeta` 锁定、`flash.locked=1` |
| 测试点 / BootROM USB（Kirin-Tool） | **有效，但必须拆机**（机主要求排除） | XDA 麒麟 710/970/980 指南；BootROM 利用来自 TASZK |
| 软件测试点（SWTP） | **不适用**（要求补丁 ≤ 2021-01） | 本机为 2024-02-01 |
| 降级后 SWTP | **被防回滚阻断** | 无签名降级路径 |
| KernelSU / APatch / Magisk | **必须已解锁 BL** | 锁定状态拒绝 `fastboot flash boot` |

### 3.2 内核与框架攻击面

| 候选 | 等级 | 结论 |
|---|---|---|
| `CONFIG_NAMESPACES` 未编译 | `CONFIG_CONFIRMED` + `REPRODUCED` | `unshare -U/-Ur` 返回 `EINVAL`，user-namespace 类提权结构性不可能 |
| 模块加载 | `CONFIG_CONFIRMED` | `MODULE_SIG_FORCE=y` + 华为签名密钥 |
| HWLOG ioctl（`hwlog_exception` / `hwlog_dubai` / `hwlog_jank`） | `SOURCE_CONFIRMED` + `ACCESS_CONFIRMED` | 2022 年 TASZK 的 `CVE-2022-22252/-22253/-22256` 代码仍在，但 SELinux `allowxperm` 白名单 + dubai 不再向 zrhung 分派 ⇒ **不可达** |
| Mali Bifrost r18p0 内核驱动 | `SOURCE_CONFIRMED` | 已知 CVE（`CVE-2021-39793`、`CVE-2022-22706`、`CVE-2023-4211` 等）**已回移修复** |
| NPU `/dev/davinci0` | `CONFIG_CONFIRMED` | 未编译，无设备节点 |
| `CVE-2026-43499` GhostLock | `SOURCE_CONFIRMED` + `CONFIG_CONFIRMED` | 漏洞路径存在且门控默认开放，但需回收栈帧 + 绕 ARM64 CFI + 绕 HHEE；**无内存写演示、无 Root** |
| `CVE-2025-38352`（POSIX CPU timers `sigqueue` UAF） | `SOURCE_CONFIRMED` + `CONFIG_CONFIRMED`；运行时 `NOT_REPRODUCED` | 唯一"代码在 + 配置开 + 普通 App 可达"的候选；离线 QEMU 约 5500 次未命中窗口 |
| `CVE-2024-53104`（uvcvideo 越界写） | `SOURCE_CONFIRMED` | 修复缺失，但需恶意 USB 视频设备 + camera 域进程；普通 App 打不开 `/dev/video*` |
| `CVE-2025-1246`（Mali **用户态**驱动越界） | `CONFIG_CONFIRMED`（版本命中 r18p0-01rel0） | 用户态缺陷，无内核写原语，不构成 Root 路径 |
| 华为框架 CVE（2023-52719、2024-36500、2024-56449、2025-31170） | `INCONCLUSIVE` | 真实公告，但**无公开技术细节与 PoC**，无法作为入口 |

### 3.3 唯一的内核实验成果

`CVE-2025-38352` 复现到的是**环境**，不是 UAF：

* 用厂商自家 4.14.116 源码在 QEMU ARM64 上干净启动（`INIT_OK`，零 KASAN/panic）。
* 参考公开 `chronomaly` 研究改写、适配本内核的竞态触发器跑了 **5500+ 次**：2332 次定时器 fire、1531 次"删除晚于回收"、**0 次 `WARN_ON_ONCE`、0 次 KASAN**。
* 诊断内核证明理论窗口存在：`run_posix_cpu_timers()` 确实会处理 `EXIT_ZOMBIE` 任务的 firing 链表（`exit_state=32`、`fired=1`，40/40）。
* 插桩内核（`unlock_task_sighand()` 后 `mdelay`，以及循环内第二版）同样 **0 命中**：删除方线程只在循环结束、定时器已 fire 之后才被唤醒。

判定：`NOT_REPRODUCED`。漏洞在该源码树中真实存在；但**未**在本内核/QEMU 组合上取得可靠复现，利用前提（KASLR 泄露、CFI 绕过、HHEE `SELINUX_PROT` 绕过）也未验证。详见 [experiments/results/stage-a.md](experiments/results/stage-a.md)。

## 4. 本仓库**不**包含什么

刻意保留在私有归档（见 [PRIVATE_ARCHIVE.md](PRIVATE_ARCHIVE.md)）：

* 竞态触发器源码及其精确时序参数。
* 人为加宽竞态窗口的插桩内核补丁。
* 任何针对本机的 KASLR 泄露手法或利用偏移。
* 完整的内核写 / Root 利用链。
* 华为专有二进制（APK、`libGLES_mali.so`、`framework.jar`、厂商源码包本体）。

如果你是华为 PSIRT 成员并希望获取被保留的材料用于协同披露，见 [SECURITY.md](SECURITY.md)。

## 5. 复现离线实验

实验使用**厂商自己公开发布的 GPL 内核源码**（见 [SOURCE_PROVENANCE.md](SOURCE_PROVENANCE.md)），全程不接触真机。

```bash
sudo apt-get install -y qemu-system-arm bc bison flex libssl-dev libelf-dev cpio make gcc
# 详见 qemu/README.md：工具链、配置、构建、initramfs、启动
```

预期干净启动输出见 [logs/sanitized/boot-clean.excerpt.log](logs/sanitized/boot-clean.excerpt.log)。

实验对**厂商源码树**做了 9 处小改动才让它能在 QEMU 上编译并启动（全部记录在 [patches/README.md](patches/README.md)），其中**没有一处**触及 `kernel/time/posix-cpu-timers.c`。

## 6. 目录结构

```
README.md / README.zh-CN.md   总览（英文 / 中文）
RESEARCH.md                   完整技术研究，含全部分轮与证据分级
DEVICE_INFO.md                脱敏设备档案与攻击面地图
SOURCE_PROVENANCE.md          厂商源码来源、SHA-256、许可
KERNEL_CONFIG/                设备配置摘录 + 实验用完整 .config
patches/                      9 处 QEMU 适配补丁（含理由与许可说明）
qemu/                         构建与启动说明、运行脚本
security/cve/                 逐 CVE 分析（适用性、补丁状态、可达性）
security/selinux/             策略摘录与 ioctl 权限审计
experiments/results/          阶段 A 数据：触发器统计、诊断内核、判定
logs/sanitized/               脱敏后的启动/诊断日志摘录
scripts/                      辅助脚本（配置校验、日志扫描、构建摘要）
LICENSES.md                   各文件组的许可清单
CITATION.cff                  引用方式
SECURITY.md                   披露联系与政策
AUDIT_REPORT.md               本次发布前的脱敏与许可审计
PRIVATE_ARCHIVE.md            被保留内容及原因
MANIFEST.sha256               全部发布文件的 SHA-256
```

## 7. 研究限制

* **单机单固件**：`HMA-AL00 10.1.0.163(C00E160R1P8)`、HarmonyOS 4.0.0、2024-02-01 补丁。其他版本可能不同。
* **不拆机**：机主明确排除拆机，因此唯一公开可证的麒麟 980 解锁原语不可用。
* **不在真机跑利用**：按机主要求，从未对真机执行任何竞态/PoC。
* **不是"不可攻破"的证明**：对已测攻击面的负面结果，不代表不存在其他漏洞。
* **QEMU ≠ 真机**：实验内核与设备内核在 9 处源码/构建点、关闭的子系统、`CONFIG_RANDOMIZE_BASE` 上均不同，所有实验结论都按此标注。

## 8. 伦理与披露

研究在个人所有设备上进行，除明确说明外均为只读操作；未变砖、未清数据、未刷任何分区。对可能影响在售华为固件的漏洞，**未**公开利用细节，详见 [SECURITY.md](SECURITY.md)。

## 9. 许可

原创文档：**CC BY 4.0**；原创脚本：**MIT**（见 [LICENSES.md](LICENSES.md)）。
内核补丁派生自厂商 GPL-2.0 内核源码，保持 **GPL-2.0**，**不重新授权**。厂商二进制不再分发。

## 10. 贡献

欢迎纠错，这也是本仓库公开的主要目的。

* **事实错误**（行号错误、CVE 归属错误、步骤失效）：请开 Issue，附文件、原结论与反证。
* **复现尝试**：如果你能在真实的 4.14.116 构建上让 CVE-2025-38352 触发 `WARN_ON_ONCE` 或 KASAN，这是最有价值的贡献——请描述方法，而不是提交武器化载荷。
* **硬件数据点**：其他麒麟 980 机型、或不同补丁级别的同款固件，对适用性表很有用。
* **许可/署名**：发现署名或许可有误请告知。

请把 PR 限制在文档与分析范围内。**不要提交利用代码、触发器源码或 KASLR/偏移材料**——这类 PR 会被关闭，材料应走 [SECURITY.md](SECURITY.md) 里的私有渠道。

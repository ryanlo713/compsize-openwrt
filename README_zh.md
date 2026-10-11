# compsize-openwrt

[English](README.md) · **中文**

面向 OpenWrt 的**静态** [`compsize`](https://github.com/kilobyte/compsize) 预编译二进制与安装包。

`compsize` 用于统计 btrfs 文件系统上一组文件实际使用的压缩算法与压缩率。OpenWrt 未收录该工具，
因此本仓库在 CI 中从上游源码构建，并发布可直接使用的产物。

## 设计要点

* **零运行时依赖。** 上游仅需要 btrfs 用户态**头文件**，不链接 `libbtrfs`，因此本仓所有二进制均**静态链接 musl**。
* **覆盖按架构而非按发行版。** 同一架构的一份产物即可用于 OpenWrt 21.02 / 22.03 / 23.05 / 24.10 及快照版。
* **可复现、可校验。** 上游 commit、头文件来源与工具链均钉在 [`upstream.lock`](upstream.lock)；
  产物随 `SHA256SUMS` 与 `BUILDINFO.txt` 一并发布。

## 支持平台

| 优先级 | OpenWrt 架构 | 交叉目标 |
| :---: | :--- | :--- |
| 1 | `aarch64_cortex-a53` | `aarch64-linux-musl` |
| 2 | `arm_cortex-a7_neon-vfpv4` | `arm-linux-musleabihf` |
| 2 | `arm_cortex-a9` | `arm-linux-musleabihf` |
| 2 | `arm_cortex-a5` | `arm-linux-musleabi` |
| 2 | `mipsel_24kc` | `mipsel-linux-musl` |
| 2 | `mips_24kc` | `mips-linux-musl` |
| 2 | `x86_64` | `x86_64-linux-musl` |
| 2 | `i386_pentium4` | `x86-linux-musl` |
| 3 | `riscv64_generic` | `riscv64-linux-musl` |

平台矩阵只在 [`build/targets.tsv`](build/targets.tsv) 定义一次，本地构建脚本与 CI 矩阵共用该文件。

## 安装

### 一键安装脚本

```sh
sh install.sh                 # 安装静态二进制到 /usr/bin/compsize
sh install.sh --ipk           # 改用 opkg 安装 .ipk（仅 opkg 体系发行版）
```

脚本会自动识别架构（优先 `DISTRIB_ARCH`，退回 `uname -m`），从本仓最新 Release 下载对应产物，
并用 `SHA256SUMS` 校验；可用 `-r owner/repo`、`-t <tag>`、`-d <dir>` 覆盖默认值。

### 手动安装

```sh
# 从 Release 页下载 compsize-<arch> 与 SHA256SUMS
sha256sum -c SHA256SUMS --ignore-missing
scp compsize-<arch> <user>@<router>:/usr/bin/compsize
ssh <user>@<router> 'chmod 755 /usr/bin/compsize'
```

### 安装包

```sh
opkg install compsize-<arch>.ipk        # opkg 体系发行版
```

安装包**未签名**且不声明任何依赖；设备未开启签名校验时，opkg 可直接安装本地未签名包。

## 用法

```
compsize [options] <file>|<dir> ...

    -b, --bytes            以字节而非人类可读单位显示
    -x, --one-file-system  不跨文件系统边界
```

```
Processed 140058 files, 133128 regular extents (196786 refs), 80886 inline.
Type       Perc     Disk Usage   Uncompressed Referenced
TOTAL       93%       14G          15G          12G
none       100%       13G          13G          10G
zstd        28%       42M         148M         148M
```

运行需要 **root** 权限（工具会下发 btrfs ioctl）。

## 构建

```sh
./build/fetch-headers.sh                     # 取 btrfs 用户态头文件（钉 btrfs-progs tag）
./build/build-static.sh                      # 全平台构建；环境变量 ZIG=<path>、ONLY=<arch>
./build/make-ipk.sh <arch> <ver> build/out/compsize-<arch> build/out
./build/make-apk.sh <arch> <ver> build/out/compsize-<arch> build/out
```

交叉编译使用 [zig](https://ziglang.org)（`zig cc -target <triple>`），版本与 SHA256 钉在 `upstream.lock`。
CI 获取工具链的顺序为：`actions/cache` → 本仓 Release 资产（`mirror-toolchain.yml`） → 上游下载站。

### 工作流

| 工作流 | 触发 | 作用 |
| :--- | :--- | :--- |
| `build.yml` | push / PR / tag `v*` | 构建矩阵与打包；打 tag 时创建 Release |
| `mirror-toolchain.yml` | 手动 | 把钉版工具链镜像为本仓 Release 资产 |
| `sdk-static.yml` | 手动 | 使用官方 OpenWrt SDK 工具链构建 |

## 发布产物

```
compsize-<arch>              静态二进制
compsize-<arch>.ipk          opkg 包（未签名、无依赖）
compsize-<arch>.apk          apk 包（apk-tools v2 格式）
install.sh                   安装脚本（已写入本仓地址）
SHA256SUMS                   全部产物的校验和
BUILDINFO.txt                可追溯信息：上游 commit、工具链版本、编译参数
```

## 限制

* 需要 root 权限，且仅对 **btrfs** 文件系统有意义。
* `Referenced` 按 extent 整体计数，可能与 `du`、`tar` 的合计不一致。
* 静态二进制比动态链接版本大几百 KB。
* 发布的 `.apk` 为 apk-tools **v2** 格式；OpenWrt 24.10 起改用 apk-tools 3，
  该版本请直接使用静态二进制，或用 OpenWrt SDK（`sdk-static.yml`）自行构建原生包。

## 许可

GPL-2.0-or-later，与上游一致。完整许可全文见 [`LICENSE`](LICENSE)；版权与对应源码信息见
[`NOTICE`](NOTICE)；第三方组件见 [`THIRD-PARTY.md`](THIRD-PARTY.md)。

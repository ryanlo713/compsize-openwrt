# compsize-openwrt

**English** · [中文](README_zh.md)

Prebuilt **static** [`compsize`](https://github.com/kilobyte/compsize) binaries and packages for OpenWrt.

`compsize` reports the compression types and the effective compression ratio used by a set of files
on a btrfs filesystem. OpenWrt does not package it, so this repository builds it from upstream source
in CI and publishes ready-to-run artifacts.

## Design

* **No runtime dependencies.** Upstream needs only the btrfs userspace *headers* — it does not link
  `libbtrfs` — so every binary here is statically linked against musl.
* **Coverage follows the architecture, not the release.** One artifact per OpenWrt architecture works
  on 21.02, 22.03, 23.05, 24.10 and snapshots alike.
* **Reproducible and verifiable.** The upstream commits, header source and toolchain are pinned in
  [`upstream.lock`](upstream.lock); artifacts are published with `SHA256SUMS` and `BUILDINFO.txt`.

## Targets

| Priority | OpenWrt architecture | Target triple |
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

The matrix is defined once in [`build/targets.tsv`](build/targets.tsv) and consumed by both the local
build script and the CI matrix.

## Install

### Installer script

```sh
sh install.sh                 # static binary -> /usr/bin/compsize
sh install.sh --ipk           # install the opkg package instead (opkg-based releases)
```

The installer detects the architecture (`DISTRIB_ARCH`, falling back to `uname -m`), downloads the
matching asset from the latest release of this repository and verifies it against `SHA256SUMS`.
Use `-r owner/repo`, `-t <tag>` or `-d <dir>` to override the defaults.

### Manual

```sh
# download compsize-<arch> and SHA256SUMS from the release page
sha256sum -c SHA256SUMS --ignore-missing
scp compsize-<arch> <user>@<router>:/usr/bin/compsize
ssh <user>@<router> 'chmod 755 /usr/bin/compsize'
```

### Package

```sh
opkg install compsize-<arch>.ipk        # opkg-based releases
```

The packages are **unsigned** and declare no dependencies. `opkg` installs local unsigned files
unless signature checking is enabled on the device.

## Usage

```
compsize [options] <file>|<dir> ...

    -b, --bytes            raw bytes instead of human-readable sizes
    -x, --one-file-system  do not cross filesystem boundaries
```

```
Processed 140058 files, 133128 regular extents (196786 refs), 80886 inline.
Type       Perc     Disk Usage   Uncompressed Referenced
TOTAL       93%       14G          15G          12G
none       100%       13G          13G          10G
zstd        28%       42M         148M         148M
```

Root privileges are required: the tool issues a btrfs ioctl.

## Build

```sh
./build/fetch-headers.sh                     # btrfs userspace headers (pinned btrfs-progs tag)
./build/build-static.sh                      # all targets; env: ZIG=<path>, ONLY=<arch>
./build/make-ipk.sh <arch> <ver> build/out/compsize-<arch> build/out
./build/make-apk.sh <arch> <ver> build/out/compsize-<arch> build/out
```

Cross-compilation uses [zig](https://ziglang.org) (`zig cc -target <triple>`); its version and SHA256
are pinned in `upstream.lock`. CI acquires it through `actions/cache` first, then from a release asset
of this repository (`mirror-toolchain.yml`), and only falls back to the upstream download host.

### Workflows

| Workflow | Trigger | Purpose |
| :--- | :--- | :--- |
| `build.yml` | push / PR / tag `v*` | build the matrix, package, create the release on tags |
| `mirror-toolchain.yml` | manual | mirror the pinned toolchain into this repository's releases |
| `sdk-static.yml` | manual | build with the official OpenWrt SDK toolchain |

## Release assets

```
compsize-<arch>              static binary
compsize-<arch>.ipk          opkg package (unsigned, no dependencies)
compsize-<arch>.apk          apk package (apk-tools v2 format)
install.sh                   installer, with the repository baked in
SHA256SUMS                   checksums of every artifact
BUILDINFO.txt                provenance: upstream commits, toolchain version, flags
```

## Limitations

* Requires root privileges and a **btrfs** filesystem.
* `compsize` counts referenced extents in whole; the *Referenced* column can therefore differ from
  `du` or `tar` totals.
* Static binaries are a few hundred KB larger than dynamically linked ones.
* The published `.apk` uses the apk-tools **v2** format. OpenWrt 24.10 and later ship apk-tools 3;
  use the static binary there, or build a native package with the OpenWrt SDK (`sdk-static.yml`).

## License

GPL-2.0-or-later, matching upstream. [`LICENSE`](LICENSE) holds the full license text;
[`NOTICE`](NOTICE) covers copyright and corresponding-source information; third-party components are
listed in [`THIRD-PARTY.md`](THIRD-PARTY.md).

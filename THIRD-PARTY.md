# Third-party components

## compsize (upstream)

| | |
| :--- | :--- |
| Project | [`kilobyte/compsize`](https://github.com/kilobyte/compsize) |
| License | GPL-2.0-or-later |
| Pinned | commit `d79eacf77abe3b799387bb8a4e07a18f1f1031e8` |
| Used | `compsize.c`, `radix-tree.c` and the headers bundled with the upstream source |

## btrfs-progs (build-time only)

`compsize` includes `<btrfs/ioctl.h>`, `<btrfs/ctree.h>` and related userspace headers. They are
obtained from btrfs-progs at build time and are **not redistributed** by this repository
(`hdr/` is not tracked).

| | |
| :--- | :--- |
| Project | [`kdave/btrfs-progs`](https://github.com/kdave/btrfs-progs) |
| License | GPL-2.0 (kernel uapi parts: GPL-2.0 WITH Linux-syscall-note) |
| Pinned | tag `v5.11` (commit `3ea5d6584c495d17868487a2f66b26a482bc9402`) |
| Layout | the `libbtrfs_headers` set, installed flat under `btrfs/` |

## zig (build-time only)

| | |
| :--- | :--- |
| Project | [ziglang.org](https://ziglang.org) |
| License | MIT |
| Pinned | 0.12.0, SHA256 verified (see [`upstream.lock`](upstream.lock)) |
| Role | cross-compiler for every target (`zig cc -target <triple>`) |

## Copyright and corresponding source

See [`NOTICE`](NOTICE). The full GPL-2.0 text is in [`LICENSE`](LICENSE).

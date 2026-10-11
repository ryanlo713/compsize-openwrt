#!/bin/sh
# Assemble an opkg-installable .ipk.
#
# OpenWrt's .ipk is a **gzip tar** (not a Debian ar archive). Its outer members are:
#     ./debian-binary (content "2.0\n")   ./data.tar.gz   ./control.tar.gz
#   control.tar.gz holds ./control; data.tar.gz holds ./usr/...
#   Note: an ar-based archive is not accepted by OpenWrt's opkg parser.
#
# Because the binary is statically linked, the control file declares no dependencies, so one
# package serves every release sharing the same architecture.
#
# Usage:  make-ipk.sh <openwrt_arch> <pkg_version> <binary> <outdir>
#   e.g.  make-ipk.sh aarch64_cortex-a53 1.0.0-1 build/out/compsize-aarch64_cortex-a53 dist
#
# The package is unsigned: opkg accepts local unsigned packages unless signature checking is on.
set -eu

ARCH="${1:?arch}"; VER="${2:?version}"; BIN="${3:?binary}"; OUT="${4:?outdir}"
[ -f "$BIN" ] || { echo "no such binary: $BIN" >&2; exit 1; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT INT HUP
mkdir -p "$WORK/ctrl" "$WORK/data/usr/bin"

cp "$BIN" "$WORK/data/usr/bin/compsize"
chmod 755 "$WORK/data/usr/bin/compsize"

# control file: no Depends field, since the binary carries no runtime dependencies
cat > "$WORK/ctrl/control" <<EOF
Package: compsize
Version: $VER
Architecture: $ARCH
Section: utils
Priority: optional
Maintainer: compsize-openwrt
Installed-Size: $(du -k "$BIN" | cut -f1)
License: GPL-2.0-or-later
Description: btrfs compression ratio statistics (static musl build)
 compsize reports used compression types and effective compression ratio for
 a set of files on a btrfs filesystem.  This build is statically linked
 against musl and therefore carries no runtime library dependencies, so a
 single package works across OpenWrt releases sharing the same architecture.
EOF

# ---- outer archive (OpenWrt ipk layout) ----
GZIP='-9n'   # drop timestamps/filenames for reproducibility
export GZIP

# --mode writes the permissions into the archive instead of relying on the host chmod behaviour
( cd "$WORK/ctrl" && tar --owner=0 --group=0 --mode='u=rw,go=r' -czf "$WORK/control.tar.gz" . )
( cd "$WORK/data" && tar --owner=0 --group=0 --mode='u=rwx,go=rx' -czf "$WORK/data.tar.gz" . )

mkdir -p "$WORK/outer"
printf '2.0\n' > "$WORK/outer/debian-binary"
cp "$WORK/data.tar.gz" "$WORK/control.tar.gz" "$WORK/outer/"

mkdir -p "$OUT"
OUTABS="$(cd "$OUT" && pwd)"
IPK="$OUTABS/compsize_${VER}_${ARCH}.ipk"
rm -f "$IPK"
( cd "$WORK/outer" && tar --owner=0 --group=0 -czf "$IPK" ./debian-binary ./data.tar.gz ./control.tar.gz )

echo ">> $IPK"
ls -l "$IPK"
echo ">> outer members (expected ./debian-binary, ./data.tar.gz, ./control.tar.gz):"
tar -tzf "$IPK"

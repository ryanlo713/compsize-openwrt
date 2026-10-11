#!/bin/sh
# Assemble an .apk package (apk-tools v2 format: a gzip tar holding .PKGINFO plus the file tree).
#
# Scope:
#   * The v2 format targets **apk-tools 2**. OpenWrt 24.10 and later ship apk-tools 3 (v3/ADB),
#     which does not accept v2 packages. On those releases prefer the static binary, or build a
#     native package with the OpenWrt SDK (see .github/workflows/sdk-static.yml).
#   * The package is unsigned; install it with `apk add --allow-untrusted <file>`.
#
# Usage:  make-apk.sh <arch> <version> <binary> <outdir>
set -eu

ARCH="${1:?arch}"; VER="${2:?version}"; BIN="${3:?binary}"; OUT="${4:?outdir}"
[ -f "$BIN" ] || { echo "no such binary: $BIN" >&2; exit 1; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT INT HUP
mkdir -p "$WORK/usr/bin"
cp "$BIN" "$WORK/usr/bin/compsize"
chmod 755 "$WORK/usr/bin/compsize"

SIZE=$(du -sb "$WORK" 2>/dev/null | cut -f1 || du -sk "$WORK" | awk '{print $1*1024}')

cat > "$WORK/.PKGINFO" <<EOF
pkgname = compsize
pkgver = $VER
pkgdesc = btrfs compression ratio statistics (static musl build)
url = https://github.com/kilobyte/compsize
builddate = $(date -u +%s)
packager = compsize-openwrt
size = $SIZE
arch = $ARCH
origin = compsize
license = GPL-2.0-or-later
EOF

mkdir -p "$OUT"
# absolute output path: the archive is created inside a subshell
OUTABS="$(cd "$OUT" && pwd)"
APK="$OUTABS/compsize_${VER}_${ARCH}.apk"
rm -f "$APK"
( cd "$WORK" && tar --owner=0 --group=0 --mode='u=rwx,go=rx' -czf "$APK" ./.PKGINFO ./usr )
echo ">> $APK"
ls -l "$APK"

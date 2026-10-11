#!/bin/sh
# compsize installer for OpenWrt (and any musl-based Linux)
#
# Usage:
#   sh install.sh                 # install the static binary to /usr/bin/compsize (recommended)
#   sh install.sh --ipk           # install the opkg package instead (opkg-based releases only)
#   sh install.sh -r owner/repo   # override the repository (assets are taken from its releases)
#   sh install.sh -t v1.0.0       # pin a release tag (default: latest)
#   sh install.sh -d /tmp         # install into another directory
#
# Notes:
#   * The binaries are statically linked against musl and have no runtime dependencies,
#     so the OpenWrt release does not matter.
#   * root is still required at run time: compsize issues a btrfs ioctl.
#
# The release workflow substitutes @REPO@ before publishing this script.
set -eu

REPO="@REPO@"
TAG=""

MODE=raw
DEST=/usr/bin
while [ $# -gt 0 ]; do
  case "$1" in
    --ipk)  MODE=ipk ;;
    -r)     REPO="$2"; shift ;;
    -t)     TAG="$2";  shift ;;
    -d)     DEST="$2"; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

case "$REPO" in
  *"@"*) echo "!! REPO is still the @REPO@ placeholder: pass -r owner/repo, or download install.sh from a release page" >&2; exit 2 ;;
esac

# ---------- 1) architecture detection ----------
detect_arch() {
  # OpenWrt: DISTRIB_ARCH already is an OpenWrt architecture name, e.g. aarch64_cortex-a53
  if [ -r /etc/openwrt_release ]; then
    a=$(sed -n "s/^DISTRIB_ARCH='\(.*\)'$/\1/p" /etc/openwrt_release | head -1)
    [ -n "$a" ] && { echo "$a"; return; }
  fi
  # fallback: map uname -m
  m=$(uname -m)
  case "$m" in
    aarch64|arm64)     echo aarch64_cortex-a53 ;;
    armv7l|armv7*)     echo arm_cortex-a7_neon-vfpv4 ;;
    armv6l|armv5*)     echo arm_cortex-a5 ;;
    mips)              echo mips_24kc ;;
    mipsel)            echo mipsel_24kc ;;
    x86_64|amd64)      echo x86_64 ;;
    i686|i386)         echo i386_pentium4 ;;
    riscv64)           echo riscv64_generic ;;
    *) echo "?" ;;
  esac
}
ARCH=$(detect_arch)
[ "$ARCH" != "?" ] || { echo "!! unsupported architecture (uname -m=$(uname -m)); select an asset manually" >&2; exit 1; }
echo ">> architecture: $ARCH"

# ---------- 2) downloader ----------
DL=""
for c in curl uclient-fetch wget; do
  if command -v "$c" >/dev/null 2>&1; then DL="$c"; break; fi
done
[ -n "$DL" ] || { echo "!! curl, uclient-fetch or wget is required" >&2; exit 1; }
echo ">> downloader: $DL"

fetch() { # fetch <url> <outfile>
  case "$DL" in
    curl)          curl -fsSL -o "$2" "$1" ;;
    uclient-fetch) uclient-fetch -q -O "$2" "$1" ;;
    wget)          wget -q -O "$2" "$1" ;;
  esac
}

if [ -n "$TAG" ]; then
  BASE="https://github.com/$REPO/releases/download/$TAG"
else
  BASE="https://github.com/$REPO/releases/latest/download"
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT INT HUP

# ---------- 3) fetch and install ----------
if [ "$MODE" = "ipk" ]; then
  command -v opkg >/dev/null 2>&1 || { echo "!! opkg not found (24.10 and later use apk); use the default binary mode" >&2; exit 1; }
  ASSET="compsize-$ARCH.ipk"
  echo ">> downloading $BASE/$ASSET"
  fetch "$BASE/$ASSET" "$TMP/$ASSET"        # keep the asset name: sha256sum -c expects it
  if fetch "$BASE/SHA256SUMS" "$TMP/SHA256SUMS" 2>/dev/null; then
    ( cd "$TMP" && grep -E "[[:space:]]${ASSET}\$" SHA256SUMS | sha256sum -c - ) \
      || { echo "!! checksum mismatch" >&2; exit 1; }
    echo ">> checksum OK"
  fi
  opkg install "$TMP/$ASSET"
  echo ">> installed via opkg.  Run:  compsize <btrfs-directory>"
  exit 0
else
  ASSET="compsize-$ARCH"
  echo ">> downloading $BASE/$ASSET"
  fetch "$BASE/$ASSET" "$TMP/$ASSET"        # keep the asset name: sha256sum -c expects it
  if fetch "$BASE/SHA256SUMS" "$TMP/SHA256SUMS" 2>/dev/null; then
    ( cd "$TMP" && grep -E "[[:space:]]${ASSET}\$" SHA256SUMS | sha256sum -c - ) \
      || { echo "!! checksum mismatch" >&2; exit 1; }
    echo ">> checksum OK"
  else
    echo ">> SHA256SUMS unavailable, skipping verification"
  fi
  mkdir -p "$DEST"
  cp "$TMP/$ASSET" "$DEST/compsize"
  chmod 755 "$DEST/compsize"
  echo ">> installed to $DEST/compsize"
  echo ">> try:   $DEST/compsize -h"
  echo ">> usage (root required):  $DEST/compsize <btrfs-mount-point>"
fi

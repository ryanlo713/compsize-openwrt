#!/bin/sh
# Cross-compile static musl binaries for every target listed in build/targets.tsv.
#
# Static linking means no libc version coupling: one artifact per architecture serves
# OpenWrt 21.02 / 22.03 / 23.05 / 24.10 and snapshots alike.
#
# Usage:
#   ZIG=/path/to/zig ./build/build-static.sh          # all targets
#   ONLY=aarch64_cortex-a53 ./build/build-static.sh   # a single target
#   (run ./build/fetch-headers.sh first to populate hdr/)
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ZIG="${ZIG:-zig}"
HDR="${HDR:-$ROOT/hdr}"
OUT="${OUT:-$ROOT/build/out}"
WORK="${WORK:-$ROOT/build/work}"
SRC="${SRC:-$WORK/compsize}"
TARGETS="${TARGETS:-$ROOT/build/targets.tsv}"
ONLY="${ONLY:-}"        # build one architecture only (used by the CI matrix); empty = all

_lock() { sed -n "s/^$1[[:space:]]*=[[:space:]]*//p" "$ROOT/upstream.lock" | tr -d '\r' | head -1; }

mkdir -p "$OUT" "$WORK"

# 1) fetch upstream compsize and check out the pinned commit
if [ ! -d "$SRC/.git" ]; then
  COMMIT=$(_lock 'compsize\.commit'); REPO=$(_lock 'compsize\.repo')
  echo ">> clone $REPO"
  git clone "$REPO" "$SRC"
  ( cd "$SRC" && git checkout -q "$COMMIT" )
fi

# 2) headers must be present
if [ ! -d "$HDR/btrfs" ]; then
  echo "!! missing $HDR/btrfs - run build/fetch-headers.sh first" >&2
  exit 1
fi

# 3) compile each target (list materialised first so the loop runs in the main shell)
LIST="$WORK/targets.list"
grep -v -E '^[[:space:]]*(#|$)' "$TARGETS" > "$LIST"

while IFS='	' read -r ARCH TIER ZT CF; do
  [ -n "${ARCH:-}" ] || continue
  if [ -n "$ONLY" ] && [ "$ARCH" != "$ONLY" ]; then continue; fi
  echo "== [$TIER] $ARCH   ($ZT   ${CF:-no extra CFLAGS})"
  # shellcheck disable=SC2086
  "$ZIG" cc -target "$ZT" ${CF:-} -O2 -std=gnu90 -static -I"$HDR" \
      "$SRC/compsize.c" "$SRC/radix-tree.c" \
      -o "$OUT/compsize-$ARCH"
done < "$LIST"

echo ">> artifacts:"
ls -l "$OUT"

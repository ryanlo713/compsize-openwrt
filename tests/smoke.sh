#!/bin/sh
# On-device smoke test for compsize: run it once and cross-check the numbers with busybox tools.
#
# Usage:  sh smoke.sh <path-to-compsize> <target-directory>
#   e.g.  sh smoke.sh ./compsize /path/to/btrfs/dir
#
# Checks:
#   1) compsize runs (exit 0) and prints a TOTAL row                      -> FAIL otherwise
#   2) `-b` Disk Usage (physical bytes) is within 5% of `du -sk` * 1024   -> FAIL otherwise
#   3) Referenced vs the `ls -lR` total is informational only (holes make them differ)
set -eu

BIN="${1:?path to compsize}"
DIR="${2:?target directory (inside a btrfs mount)}"

[ -x "$BIN" ] || { echo "FAIL: not executable -> $BIN" >&2; exit 1; }
[ -d "$DIR" ] || { echo "FAIL: not a directory -> $DIR" >&2; exit 1; }

echo "== 0) identity (compsize requires root)"
id

echo "== 1) compsize (human readable)"
$BIN "$DIR" || { echo "FAIL: compsize exited non-zero" >&2; exit 1; }

echo "== 2) compsize -b (raw bytes)"
RAW=$($BIN -b "$DIR")
echo "$RAW"

TOTAL=$(echo "$RAW" | awk '$1=="TOTAL"{print; exit}')
[ -n "$TOTAL" ] || { echo "FAIL: no TOTAL row" >&2; exit 1; }

CS_DISK=$(echo "$TOTAL" | awk '{print $3}')
CS_REF=$(echo  "$TOTAL" | awk '{print $5}')
echo "compsize Disk=$CS_DISK  Referenced=$CS_REF"

echo "== 3) cross-check: du -sk"
PHY=$(du -sk "$DIR" | awk '{print $1}')
PHY_B=$((PHY * 1024))
echo "du physical=$PHY_B B"

echo "== 4) cross-check: ls -lR total (apparent size)"
APP=$(ls -lR "$DIR" | awk '/^-/{s+=$5} END{print s+0}')
echo "ls apparent=$APP B"

echo "== 5) verdict"
awk -v a="$CS_DISK" -v b="$PHY_B" 'BEGIN{
  if (b<=0) { print "WARN: du reported 0, skipping comparison"; exit 0 }
  d=(a-b)/b; if (d<0) d=-d
  printf "disk vs du deviation = %.3f%%\n", d*100
  if (d>0.05) { print "FAIL: deviation > 5%"; exit 1 }
  print "PASS: compsize works and agrees with du (<= 5%)"
}'
echo "(info) Referenced=$CS_REF vs apparent=$APP - a difference is expected with holes/reflinks"

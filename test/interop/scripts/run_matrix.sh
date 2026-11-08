#!/bin/bash
# usage: run_matrix.sh <interop-dir> <work-dir> <out-tsv>
# Needs: zstd brotli lz4 xz gzip bzip2 GNU-tar bsdtar and the official 7zz
# (default ~/7zz/7zz, override with SEVENZ=/path/to/7zz). Linux only.
# <work-dir> must not exist yet or be empty; it receives one dir per cell
# (cellN/ = extracted output, cellN.log = stdout+stderr). Do not commit it.
# Every cell runs in a fresh empty directory. Columns of the TSV:
# n, file, tool, exit, verify, first_line, top_level_of_out, command
I="$1"; W="$2"; OUT="$3"
BIN=$(mktemp -d); ln -s "${SEVENZ:-$HOME/7zz/7zz}" "$BIN/7zz"
export PATH="$BIN:$PATH" LC_ALL=C.UTF-8
SUMS="$I/corpus/SHA256SUMS"
EXPECT_TXT=$(grep ' text512k.txt$' "$SUMS" | cut -d' ' -f1)
mkdir -p "$W"; n=0
printf 'n\tfile\ttool\texit\tverify\tfirst_line\ttop_level\tcommand\n' > "$OUT"

first_line() { # $1 = log file, $2 = exit code
  local l
  [ "$2" = 0 ] && return 0
  l=$(grep -m1 -E 'ERROR|rror|nrecogni|nsupport|nvalid|nknown|Can not|Cannot|Can.t |not a |ailed|ncorrect|orrupt|runcat|No such|nexpected|Bad |bad |does not|not in' "$1" | head -c 300)
  # 7zz puts the reason on the line after "ERROR: <path>"; keep both
  case "$l" in ERROR:*) l="$l -- $(grep -m1 -A1 -F -- "$l" "$1" | sed -n 2p)" ;; esac
  if [ -z "$l" ] && [ "$2" != 0 ]; then l=$(grep -v '^[[:space:]]*$' "$1" | head -1 | head -c 300); fi
  printf '%s' "$l" | tr '\t\r' '  '
}

# c <file-relative-to-windows/> <tool label> <vmode: single|tree|none> <command using $F $D>
c() {
  local file="$1" tool="$2" vmode="$3" cmd="$4"
  n=$((n+1)); local D="$W/cell$n"; mkdir -p "$D"
  local F="$I/windows/$file" rc verify top disp
  env F="$F" D="$D" timeout 300 bash -c "set -o pipefail; $cmd" > "$W/cell$n.log" 2>&1
  rc=$?
  case "$vmode" in
    single)
      if [ -f "$D/text512k.txt" ]; then
        a=$(sha256sum "$D/text512k.txt" | cut -d' ' -f1)
        [ "$a" = "$EXPECT_TXT" ] && verify="sha256 OK" || verify="sha256 MISMATCH"
      else verify="no output file"; fi ;;
    tree)
      ok=$( (cd "$D" && sha256sum -c "$SUMS" 2>/dev/null | grep -c ': OK$') )
      verify="$ok/9 sha256 OK" ;;
    *) verify="-" ;;
  esac
  top=$(ls -A "$D" 2>/dev/null | head -8 | tr '\n' ' ' | head -c 120)
  disp=$(printf '%s' "$cmd" | sed -e "s#\"\$F\"#windows/$file#g" -e "s#\"\$D\"#OUT#g" -e 's#\$D#OUT#g')
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$n" "$file" "$tool" "$rc" "$verify" "$(first_line "$W/cell$n.log" "$rc")" "$top" "$disp" >> "$OUT"
}
# no-tool marker row
none() { n=$((n+1)); printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$n" "$1" "$2" "-" "無工具" "無 apt 套件，依規定不自編" "-" "-" >> "$OUT"; }

# one-step then (if it fails and leaves a .tar) two-step for 7zz
sevenzip_chain() {
  local file="$1" before=$n
  c "$file" "7zz 26.05 (一步)" tree '7zz x -y -o"$D" "$F"'
  local line; line=$(tail -1 "$OUT"); local D="$W/cell$n"
  if ! printf '%s' "$line" | grep -q '9/9 sha256 OK' && ls "$D"/*.tar >/dev/null 2>&1; then
    c "$file" "7zz 26.05 (兩步)" tree '7zz x -y -o"$D/s1" "$F" > /dev/null && 7zz x -y -o"$D" "$D"/s1/*.tar'
  fi
}

# ---- single-file formats ----
for ext in zst br lz4 lz5 liz xz gz bz2; do
  f="single/text512k.txt.$ext"
  case $ext in
    zst) c "$f" "zstd 1.5.5" single 'zstd -d -q -o "$D/text512k.txt" "$F"' ;;
    br)  c "$f" "brotli 1.1.0" single 'brotli -d -o "$D/text512k.txt" "$F"' ;;
    lz4) c "$f" "lz4 1.9.4" single 'lz4 -d -q "$F" "$D/text512k.txt"' ;;
    lz5|liz) none "$f" "專用 CLI"
         c "$f" "(附加) zstd 1.5.5" single 'zstd -dc "$F" > "$D/text512k.txt"'
         c "$f" "(附加) lz4 1.9.4" single 'lz4 -dc "$F" > "$D/text512k.txt"'
         c "$f" "(附加) lz4 1.9.4 (-t)" none 'lz4 -t "$F"' ;;
    xz)  c "$f" "xz 5.4.5" single 'xz -dc "$F" > "$D/text512k.txt"' ;;
    gz)  c "$f" "gzip 1.12" single 'gzip -dc "$F" > "$D/text512k.txt"' ;;
    bz2) c "$f" "bzip2 1.0.8" single 'bzip2 -dc "$F" > "$D/text512k.txt"' ;;
  esac
  c "$f" "GNU tar 1.35 (自動偵測)" single 'tar -xf "$F" -C "$D"'
  c "$f" "bsdtar 3.7.2" single 'bsdtar -xf "$F" -C "$D"'
  c "$f" "7zz 26.05" single '7zz x -y -o"$D" "$F"'
done

# ---- tar chains ----
for ext in zst br lz4 lz5 liz gz xz bz2; do
  f="chain/corpus.tar.$ext"
  case $ext in
    zst) c "$f" "zstd 1.5.5 | GNU tar 1.35" tree 'zstd -dc "$F" | tar -xf - -C "$D"'
         c "$f" "GNU tar 1.35 (--zstd)" tree 'tar --zstd -xf "$F" -C "$D"' ;;
    br)  c "$f" "brotli 1.1.0 | GNU tar 1.35" tree 'brotli -dc "$F" | tar -xf - -C "$D"'
         c "$f" "GNU tar 1.35 (-I brotli)" tree 'tar -I brotli -xf "$F" -C "$D"' ;;
    lz4) c "$f" "lz4 1.9.4 | GNU tar 1.35" tree 'lz4 -dc "$F" | tar -xf - -C "$D"'
         c "$f" "GNU tar 1.35 (-I lz4)" tree 'tar -I lz4 -xf "$F" -C "$D"' ;;
    lz5|liz) none "$f" "專用 CLI"
         c "$f" "(附加) zstd 1.5.5 | GNU tar 1.35" tree 'zstd -dc "$F" | tar -xf - -C "$D"'
         c "$f" "(附加) lz4 1.9.4 | GNU tar 1.35" tree 'lz4 -dc "$F" | tar -xf - -C "$D"' ;;
    gz)  c "$f" "gzip 1.12 | GNU tar 1.35" tree 'gzip -dc "$F" | tar -xf - -C "$D"'
         c "$f" "GNU tar 1.35 (--gzip)" tree 'tar --gzip -xf "$F" -C "$D"' ;;
    xz)  c "$f" "xz 5.4.5 | GNU tar 1.35" tree 'xz -dc "$F" | tar -xf - -C "$D"'
         c "$f" "GNU tar 1.35 (--xz)" tree 'tar --xz -xf "$F" -C "$D"' ;;
    bz2) c "$f" "bzip2 1.0.8 | GNU tar 1.35" tree 'bzip2 -dc "$F" | tar -xf - -C "$D"'
         c "$f" "GNU tar 1.35 (--bzip2)" tree 'tar --bzip2 -xf "$F" -C "$D"' ;;
  esac
  c "$f" "GNU tar 1.35 (自動偵測)" tree 'tar -xf "$F" -C "$D"'
  c "$f" "bsdtar 3.7.2" tree 'bsdtar -xf "$F" -C "$D"'
  sevenzip_chain "$f"
done

# ---- 7z containers ----
for f in zstd brotli lz4 lz5 lizard flzma2 lzma2 zstd-mt4 brotli-mt4; do
  p="7z/corpus-$f.7z"
  c "$p" "7zz 26.05 (t)" none '7zz t "$F"'
  case $f in *-mt4) continue ;; esac
  c "$p" "7zz 26.05 (x)" tree '7zz x -y -o"$D" "$F"'
  c "$p" "bsdtar 3.7.2 (-tf)" none 'bsdtar -tf "$F"'
  c "$p" "bsdtar 3.7.2 (-xf)" tree 'bsdtar -xf "$F" -C "$D"'
done
echo "cells: $n"

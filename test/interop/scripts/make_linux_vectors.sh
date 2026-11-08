#!/bin/bash
# Build the Linux-side interop vectors under <interop-dir>/linux/.
# usage: make_linux_vectors.sh <interop-dir> <stage-dir> <results.tsv> <unlisted.tsv>
# Needs: zstd brotli lz4 GNU-tar bsdtar (Ubuntu 24.04 packages). Linux only.
# A vector is kept only if the tool that wrote it can read it back and the
# decoded bytes match (sha256). Anything else goes to <unlisted.tsv>.
# <stage-dir> holds scratch files (sparse payload, verify dirs); do not commit it.
I="$1"; ST="$2"; RES="$3"; UNL="$4"
export LC_ALL=C.UTF-8
CORPUS="$(cd "$I/corpus" && pwd)"; LIN="$I/linux"
mkdir -p "$ST" && ST="$(cd "$ST" && pwd)"
EXPECT_TXT=$(grep ' text512k.txt$' "$CORPUS/SHA256SUMS" | cut -d' ' -f1)
EXPECT_A=$(grep ' a.txt$' "$CORPUS/SHA256SUMS" | cut -d' ' -f1)
EXPECT_AB=$(cat "$CORPUS/a.txt" "$CORPUS/b-crlf.txt" | sha256sum | cut -d' ' -f1)

# sparse payload: 4 MiB hole with 3 small writes (HEAD at 0, MIDDLE at 2 MiB, TAIL at the end)
SP="$ST/sparse"; rm -rf "$SP"; mkdir -p "$SP"
( cd "$SP" && truncate -s 4M sparse.bin \
  && printf 'HEAD'   | dd of=sparse.bin bs=1 seek=0       conv=notrunc status=none \
  && printf 'MIDDLE' | dd of=sparse.bin bs=1 seek=2097152 conv=notrunc status=none \
  && printf 'TAIL'   | dd of=sparse.bin bs=1 seek=4194300 conv=notrunc status=none )
EXPECT_SP=$(sha256sum "$SP/sparse.bin" | cut -d' ' -f1)
SP_ALLOC=$(stat -c '%b blocks of %B bytes' "$SP/sparse.bin")

for d in tar zstd zstd-frames brotli lz4; do rm -rf "$LIN/$d"; mkdir -p "$LIN/$d"; done
printf 'name\tcwd\tcreate\tbytes\tsha256\thead16\tverify\tresult\tpayload_sha\tprobe\n' > "$RES"
printf 'name\tcreate\treason\n' > "$UNL"
echo "sparse payload sha256=$EXPECT_SP size=$(stat -c %s "$SP/sparse.bin") alloc=$SP_ALLOC" > "$ST/sparse.info"

show() { sed -e 's#"\$OUT"#<out>#g; s#\$OUT#<out>#g' -e 's#"\$P"#<dir>/payload#g; s#\$P#<dir>/payload#g' -e 's#"\$D"#<dir>#g; s#\$D#<dir>#g' | tr '\t\n' '  '; }

# tarprobe <decoder-command>: which tar dialect and how the long name was stored
tarprobe() {
  echo "m=\$($1 | head -c 512 | tail -c +258 | head -c 8 | od -An -tx1 | tr -d ' \\n'); case \$m in 7573746172003030) f=posix-ustar;; 7573746172202000) f=gnu-oldgnu;; *) f=\$m;; esac; echo \"tar-magic=\$f\"; echo \"LongLink-entries=\$($1 | grep -a -c '@LongLink')\"; echo \"PaxHeader-entries=\$($1 | grep -a -c 'PaxHeader')\""
}
ZPROBE='zstd -lv "$OUT" 2>&1 | grep -E "Window Size|Check:|Decompressed Size|Frames|Skippable" | tr -s " " | tr "\n" ";"'

unl() { printf '%s\t%s\t%s\n' "$1" "$(printf '%s' "$2" | show)" "$(printf '%s' "$3" | tr '\t\n' '  ' | head -c 300)" >> "$UNL"; }

# vec <name-under-linux/> <cwd> <create-cmd> <vmode: file:<sha>|tree|sparse> <verify-cmd> <probe-cmd>
vec() {
  local name="$1" cwd="$2" create="$3" vmode="$4" verify="$5" probe="$6"
  local OUT="$LIN/$name" D; D=$(mktemp -d -p "$ST"); mkdir -p "$D/x"
  ( cd "$cwd" && env OUT="$OUT" timeout 300 bash -c "set -o pipefail; $create" ) > "$D/create.log" 2>&1; local crc=$?
  if [ $crc -ne 0 ] || [ ! -s "$OUT" ]; then unl "$name" "$create" "create exit=$crc: $(head -c 200 "$D/create.log")"; rm -f "$OUT"; return; fi
  env OUT="$OUT" D="$D/x" P="$D/x/payload" timeout 300 bash -c "set -o pipefail; $verify" > "$D/verify.log" 2>&1; local vrc=$?
  local ok=0 got=""
  case "$vmode" in
    file:*) got=$(sha256sum "$D/x/payload" 2>/dev/null | cut -d' ' -f1); [ $vrc = 0 ] && [ "$got" = "${vmode#file:}" ] && ok=1 ;;
    tree)   got="$(cd "$D/x" && sha256sum -c "$CORPUS/SHA256SUMS" 2>/dev/null | grep -c ': OK$')/9"; [ $vrc = 0 ] && [ "$got" = "9/9" ] && ok=1 ;;
    sparse) got=$(sha256sum "$D/x/sparse.bin" 2>/dev/null | cut -d' ' -f1); local sz; sz=$(stat -c %s "$D/x/sparse.bin" 2>/dev/null)
            [ $vrc = 0 ] && [ "$got" = "$EXPECT_SP" ] && [ "$sz" = 4194304 ] && ok=1 ;;
  esac
  if [ $ok != 1 ]; then unl "$name" "$create" "verify exit=$vrc got=$got: $(head -c 200 "$D/verify.log")"; rm -f "$OUT"; return; fi
  local pr=""; [ -n "$probe" ] && pr=$(env OUT="$OUT" bash -c "$probe" 2>&1 | tr '\n' ' ' | head -c 400)
  local rel; case "$cwd" in "$CORPUS") rel="corpus";; "$SP") rel="sparse-stage";; esac
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$rel" "$(printf '%s' "$create" | show)" "$(stat -c %s "$OUT")" \
    "$(sha256sum "$OUT" | cut -d' ' -f1)" "$(xxd -l 16 -p "$OUT" | tr 'a-f' 'A-F' | sed -E 's/(..)/\1 /g; s/ $//')" \
    "$(printf '%s' "$verify" | show)" "PASS" "${vmode#file:}" "$pr" >> "$RES"
}

C="$CORPUS"
# ---- 1. tar + zstd / lz4, corpus as payload (cwd = corpus, members = *) ----
vec tar/corpus.gnutar-gnu.tar.zst "$C" 'tar --zstd -cf "$OUT" -- *' tree 'tar --zstd -xf "$OUT" -C "$D"' "$(tarprobe 'zstd -dc "$OUT"')"
vec tar/corpus.gnutar-pax.tar.zst "$C" 'tar --format=pax --zstd -cf "$OUT" -- *' tree 'tar --zstd -xf "$OUT" -C "$D"' "$(tarprobe 'zstd -dc "$OUT"')"
vec tar/corpus.bsdtar-default.tar.zst "$C" 'bsdtar --zstd -cf "$OUT" -- *' tree 'bsdtar -xf "$OUT" -C "$D"' "$(tarprobe 'zstd -dc "$OUT"')"
vec tar/corpus.bsdtar-gnutar.tar.zst "$C" 'bsdtar --format gnutar --zstd -cf "$OUT" -- *' tree 'bsdtar -xf "$OUT" -C "$D"' "$(tarprobe 'zstd -dc "$OUT"')"
vec tar/corpus.bsdtar-default.tar.lz4 "$C" 'bsdtar --lz4 -cf "$OUT" -- *' tree 'bsdtar -xf "$OUT" -C "$D"' "$(tarprobe 'lz4 -dc "$OUT"')"
# ---- 7. sparse file (cwd = sparse stage; payload sha256 recorded separately) ----
vec tar/sparse.gnutar-sparse-gnu.tar.zst "$SP" 'tar --sparse --format=gnu --zstd -cf "$OUT" sparse.bin' sparse 'tar --zstd -xf "$OUT" -C "$D"' \
  'echo "type-flag=$(zstd -dc "$OUT" | head -c 512 | tail -c +157 | head -c 1)"; zstd -dc "$OUT" | wc -c'
vec tar/sparse.gnutar-sparse-pax.tar.zst "$SP" 'tar --sparse --format=pax --zstd -cf "$OUT" sparse.bin' sparse 'tar --zstd -xf "$OUT" -C "$D"' \
  'echo "GNU.sparse-keys=$(zstd -dc "$OUT" | grep -a -c "GNU.sparse")"; zstd -dc "$OUT" | wc -c'
vec tar/sparse.bsdtar-default.tar.zst "$SP" 'bsdtar --zstd -cf "$OUT" sparse.bin' sparse 'bsdtar -xf "$OUT" -C "$D"' \
  'echo "type-flag=$(zstd -dc "$OUT" | head -c 512 | tail -c +157 | head -c 1)"; echo "GNU.sparse-keys=$(zstd -dc "$OUT" | grep -a -c "GNU.sparse")"; zstd -dc "$OUT" | wc -c'
# ---- 2. zstd single file (cwd = corpus, payload text512k.txt) ----
vec zstd/zstd-19.text512k.txt.zst "$C" 'zstd -19 -q -f -o "$OUT" text512k.txt' "file:$EXPECT_TXT" 'zstd -d -q -f -o "$P" "$OUT"' "$ZPROBE"
vec zstd/zstd-T0-long31.text512k.txt.zst "$C" 'zstd -T0 --long=31 -q -f -o "$OUT" text512k.txt' "file:$EXPECT_TXT" 'zstd -d --long=31 -q -f -o "$P" "$OUT"' "$ZPROBE"
vec zstd/zstd-T0-long31-stdin.text512k.txt.zst "$C" 'cat text512k.txt | zstd -T0 --long=31 -q > "$OUT"' "file:$EXPECT_TXT" 'zstd -d --long=31 -q -f -o "$P" "$OUT"' "$ZPROBE"
vec zstd/zstd-no-check.text512k.txt.zst "$C" 'zstd --no-check -q -f -o "$OUT" text512k.txt' "file:$EXPECT_TXT" 'zstd -d -q -f -o "$P" "$OUT"' "$ZPROBE"
vec zstd/zstd-no-content-size.text512k.txt.zst "$C" 'zstd --no-content-size -q -f -o "$OUT" text512k.txt' "file:$EXPECT_TXT" 'zstd -d -q -f -o "$P" "$OUT"' "$ZPROBE"
vec zstd/zstd-stdin.text512k.txt.zst "$C" 'cat text512k.txt | zstd -q > "$OUT"' "file:$EXPECT_TXT" 'zstd -d -q -f -o "$P" "$OUT"' "$ZPROBE"
# ---- 3. multi-frame and hand-made skippable frames (payload: a.txt then b-crlf.txt) ----
SKIP="printf '\\x50\\x2a\\x4d\\x18\\x10\\x00\\x00\\x00'; printf '0123456789ABCDEF'"
vec zstd-frames/concat.a-then-b.zst "$C" 'T=$(mktemp -d); zstd -q -c a.txt > $T/A.zst; zstd -q -c b-crlf.txt > $T/B.zst; cat $T/A.zst $T/B.zst > "$OUT"' "file:$EXPECT_AB" 'zstd -d -q -c "$OUT" > "$P"' "$ZPROBE"
vec zstd-frames/skippable-before.a.zst "$C" "T=\$(mktemp -d); zstd -q -c a.txt > \$T/A.zst; { $SKIP; cat \$T/A.zst; } > \"\$OUT\"" "file:$EXPECT_A" 'zstd -d -q -c "$OUT" > "$P"' "$ZPROBE"
vec zstd-frames/skippable-between.a-b.zst "$C" "T=\$(mktemp -d); zstd -q -c a.txt > \$T/A.zst; zstd -q -c b-crlf.txt > \$T/B.zst; { cat \$T/A.zst; $SKIP; cat \$T/B.zst; } > \"\$OUT\"" "file:$EXPECT_AB" 'zstd -d -q -c "$OUT" > "$P"' "$ZPROBE"
# ---- 4. zstd writing the lz4 frame format ----
vec lz4/zstd-format-lz4.text512k.txt.lz4 "$C" 'zstd --format=lz4 -q -f -o "$OUT" text512k.txt' "file:$EXPECT_TXT" 'zstd -d -q -f -o "$P" "$OUT"' ''
# ---- 5. brotli ----
for qw in "0 10" "0 24" "5 16" "5 22" "11 10" "11 16" "11 22" "11 24"; do set -- $qw
  vec "brotli/brotli-q$1-w$2.text512k.txt.br" "$C" "brotli -q $1 -w $2 -c text512k.txt > \"\$OUT\"" "file:$EXPECT_TXT" 'brotli -d -c "$OUT" > "$P"' ''
done
vec brotli/corpus.gnutar.tar.br "$C" 'tar cf - -- * | brotli -c > "$OUT"' tree 'brotli -d -c "$OUT" | tar -xf - -C "$D"' ''
vec brotli/brotli-q5-large-window30.text512k.txt.br "$C" 'brotli -q 5 --large_window=30 -c text512k.txt > "$OUT"' "file:$EXPECT_TXT" 'brotli -d --large_window=30 -c "$OUT" > "$P"' ''
# ---- 6. lz4 ----
for o in "-B4" "-B7" "-BD" "-BX" "--no-frame-crc" "--content-size" "-l" "-B4 -BD"; do
  n=$(printf '%s' "$o" | tr -d ' ' | sed 's/^-*//; s/-/_/g'); [ "$o" = "--no-frame-crc" ] && n=no-frame-crc; [ "$o" = "--content-size" ] && n=content-size; [ "$o" = "-l" ] && n=legacy; [ "$o" = "-B4 -BD" ] && n=B4-BD
  vec "lz4/lz4-$n.text512k.txt.lz4" "$C" "lz4 -q -f $o text512k.txt \"\$OUT\"" "file:$EXPECT_TXT" 'lz4 -d -q -f "$OUT" "$P"' ''
done
vec lz4/concat.a-then-b.lz4 "$C" 'T=$(mktemp -d); lz4 -q -f a.txt $T/A.lz4; lz4 -q -f b-crlf.txt $T/B.lz4; cat $T/A.lz4 $T/B.lz4 > "$OUT"' "file:$EXPECT_AB" 'lz4 -d -q -f "$OUT" "$P"' ''
# ---- 8. lz5 / lizard: no apt package, not built from source ----
unl "(lz5 vectors)" "-" "未產生：Ubuntu 24.04 沒有 lz5 套件，依規定不從原始碼編譯"
unl "(lizard vectors)" "-" "未產生：Ubuntu 24.04 沒有 lizard 套件，依規定不從原始碼編譯"
echo "sparse payload: $(cat "$ST/sparse.info")"; echo "listed: $(($(wc -l < "$RES")-1))  unlisted: $(($(wc -l < "$UNL")-1))"

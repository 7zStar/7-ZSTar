#!/usr/bin/env bash
# 7-ZSTar interop matrix for the Linux gcc build of 7zz.
#
#   build/linux/interop-check.sh [windows|linux|apt|all] [--7zz PATH]
#
#   windows  the files in test/interop/windows/ (made by the Windows build);
#            every one is expected to be readable.
#   linux    the vectors in test/interop/linux/ (made by apt's zstd, brotli,
#            lz4, GNU tar, bsdtar); expected verdicts are the Windows results
#            of test/interop/REPORT.md section 8 (see WIN_EXPECT below).
#   apt      7zz-made files read by the apt CLIs, and the other way round.
#   all      all three (default)
#
# Output is Markdown tables on stdout (the rows are pasted into
# build/linux/REPORT.md) plus a summary.  Set INTEROP_LOG_DIR to an existing
# directory to keep the raw 7zz l / t / x output of every file.  Exit status
# is 0 only when every verdict is the expected one.
#
# Per file: "7zz l" (the Type chain and, for chains, whether the tar members
# are listed directly = drill-down), "7zz t", "7zz x" into a fresh directory,
# then the extracted content against test/interop/corpus/SHA256SUMS (or the
# payload sha256 the MANIFEST gives for single-file vectors).
#
# Verdicts (the first four as in build/Test-Interop.ps1; ERROR-EXIT is this
# script's own intermediate verdict, mapped to REJECTED-CLEAN or FAIL later):
#   PASS             exit 0 everywhere and the content is right
#   REJECTED-CLEAN   an expected rejection with an ordinary 7-Zip error exit
#   UPSTREAM-LIMIT   pax-format GNU sparse 1.0 entries left compacted as
#                    GNUSparseFile.<n>/<name> (official 7-Zip does the same)
#   ERROR-EXIT       non-zero exit with an ordinary 7-Zip error code where a
#                    clean result was expected (a rejection is only expected
#                    for the vectors listed in WIN_EXPECT)
#   FAIL / REJECTED-UNCLEAN / UNEXPECTED-OK   anything else

set -u
export LC_ALL=C.UTF-8

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd "$SCRIPT_DIR/../.." && pwd)
SZ=${SEVENZZ:-$REPO/CPP/7zip/Bundles/Alone2/b/g/7zz}
MODE=all
while [ $# -gt 0 ]; do
    case $1 in
        windows|linux|apt|all) MODE=$1 ;;
        --7zz) shift; SZ=${1:-} ;;
        *) echo "usage: $0 [windows|linux|apt|all] [--7zz PATH]" >&2; exit 2 ;;
    esac
    shift
done
case $SZ in /*) ;; *) SZ=$PWD/$SZ ;; esac
[ -x "$SZ" ] || { echo "7zz not found or not executable: $SZ" >&2; exit 2; }

IOP=$REPO/test/interop
CORPUS=$IOP/corpus
SUMS=$CORPUS/SHA256SUMS
LOGDIR=${INTEROP_LOG_DIR:-}
LINUX_MANIFEST=$IOP/linux/MANIFEST.md

WORK=$(mktemp -d "${TMPDIR:-/tmp}/7zstar-interop.XXXXXX") || exit 2
trap 'rm -rf -- "$WORK"' EXIT
case $WORK in /*) ;; *) echo "mktemp returned a relative path" >&2; exit 2 ;; esac

# Windows results of test/interop/REPORT.md section 8 ("Linux -> Windows"):
# 32 PASS, lz4-legacy REJECTED-CLEAN, and four UPSTREAM-LIMIT vectors.
# Everything not listed here is expected to be PASS.
declare -A WIN_EXPECT=(
    ["lz4/lz4-legacy.text512k.txt.lz4"]=REJECTED-CLEAN
    ["tar/corpus.bsdtar-default.tar.zst"]=UPSTREAM-LIMIT
    ["tar/corpus.bsdtar-default.tar.lz4"]=UPSTREAM-LIMIT
    ["tar/sparse.gnutar-sparse-pax.tar.zst"]=UPSTREAM-LIMIT
    ["tar/sparse.bsdtar-default.tar.zst"]=UPSTREAM-LIMIT
)

# Size of the rebuilt sparse payload, as stated in linux/MANIFEST.md
# ("重建後的 `sparse.bin`：4194304 bytes").
SPARSE_SIZE=$(grep -oP '重建後的 `sparse\.bin`：\K[0-9]+(?= bytes)' "$LINUX_MANIFEST" 2>/dev/null | head -1)
[ -n "$SPARSE_SIZE" ] || { echo "cannot read the sparse.bin size from $LINUX_MANIFEST" >&2; exit 2; }

BAD_RUNS=0     # verdicts that are not the expected one
N_ROWS=0

sha() { sha256sum -- "$1" | cut -d' ' -f1; }

# sz <args...>: combined output in OUT, exit code in RC
sz() { OUT=$("$SZ" "$@" 2>&1); RC=$?; }

log_out() { # <label> <name> <text>
    [ -n "$LOGDIR" ] || return 0
    printf '== %s\n%s\n' "$1" "$3" >> "$LOGDIR/$(printf '%s' "$2" | tr '/ ' '__').log"
}

# ---------------------------------------------------------------------------
# corpus bookkeeping
# ---------------------------------------------------------------------------

declare -A EXP_CORPUS=()
while IFS= read -r line; do
    [ -n "$line" ] || continue
    EXP_CORPUS["${line#*  }"]=${line%% *}
done < "$SUMS"
# The Linux and Windows tars were made with "<tool> ... *" inside corpus/, so
# SHA256SUMS itself is a member next to the nine files it lists.
EXP_CORPUS["SHA256SUMS"]=$(sha "$SUMS")
N_CORPUS=${#EXP_CORPUS[@]}

# check_output <kind> <outdir> <payload-sha> [<expected-single-name>]
# kind: single | corpus | sparse.  Sets VERDICT (PASS / UPSTREAM-LIMIT / FAIL)
# and DETAIL.
check_output() {
    local kind=$1 outdir=$2 psha=${3:-} want_name=${4:-} f rel
    local -a bad=() produced=() sparse_files=()
    mapfile -d '' -t produced < <(find "$outdir" -type f -print0 | sort -z)
    case $kind in
        single)
            if [ -z "$psha" ]; then bad+=("no payload sha256")
            elif [ "${#produced[@]}" -ne 1 ]; then bad+=("expected 1 output file, got ${#produced[@]}")
            elif [ "$(sha "${produced[0]}")" != "$psha" ]; then bad+=("payload sha256 mismatch")
            elif [ -n "$want_name" ] && [ "$(basename "${produced[0]}")" != "$want_name" ]; then bad+=("output named $(basename "${produced[0]}"), want $want_name")
            fi ;;
        sparse)
            f=$(find "$outdir" -type f -name sparse.bin | head -1)
            if [ -z "$psha" ]; then bad+=("no payload sha256")
            elif [ -z "$f" ]; then bad+=("missing sparse.bin")
            elif [ "$(stat -c %s "$f")" -ne "$SPARSE_SIZE" ]; then bad+=("sparse.bin is $(stat -c %s "$f") bytes, want $SPARSE_SIZE")
            elif [ "$(sha "$f")" != "$psha" ]; then bad+=("sparse.bin sha256 mismatch"); fi ;;
        corpus)
            for rel in "${!EXP_CORPUS[@]}"; do
                if [ ! -f "$outdir/$rel" ]; then bad+=("missing $rel"); continue; fi
                [ "$(sha "$outdir/$rel")" = "${EXP_CORPUS[$rel]}" ] || bad+=("sha256 mismatch $rel")
            done
            if [ "${#produced[@]}" -gt "$N_CORPUS" ]; then bad+=("$((${#produced[@]} - N_CORPUS)) unexpected extra file(s)"); fi ;;
    esac
    # pax-format GNU sparse 1.0 entries: GNUSparseFile.<n>/<name> holding the
    # compacted data.  Only the complaints those members account for are
    # excused; anything else going wrong in the same archive is still a FAIL.
    local -a sp_names=() residual=()
    for f in "${produced[@]}"; do
        rel=${f#"$outdir"/}
        case $rel in GNUSparseFile.*) sp_names+=("$(basename "$f")"); sparse_files+=("$rel") ;; esac
    done
    local b n explained
    for b in "${bad[@]}"; do
        explained=0
        for n in "${sp_names[@]}"; do
            case $b in
                "missing $n"|"sha256 mismatch $n"|"$n sha256 mismatch"|"$n is "*" bytes, want "*) explained=1 ;;
            esac
        done
        if [[ $b =~ ^([0-9]+)\ unexpected\ extra\ file\(s\)$ ]] && [ "${BASH_REMATCH[1]}" -le "${#sp_names[@]}" ]; then explained=1; fi
        [ "$explained" -eq 1 ] || residual+=("$b")
    done
    if [ "${#bad[@]}" -gt 0 ] && [ "${#sparse_files[@]}" -gt 0 ] && [ "${#residual[@]}" -eq 0 ]; then
        VERDICT=UPSTREAM-LIMIT
        DETAIL="pax GNU.sparse 1.0 entry left compacted as ${sparse_files[*]}"
    elif [ "${#bad[@]}" -gt 0 ]; then
        VERDICT=FAIL
        DETAIL=$(IFS=';'; echo "${bad[*]}")
    else
        VERDICT=PASS
        DETAIL=
    fi
}

# first_error <text>: first line that says ERROR, else last non-empty line
first_error() {
    local e
    e=$(printf '%s\n' "$1" | grep -m1 -E 'Open ERROR|Can.t open') || e=$(printf '%s\n' "$1" | grep -m1 -E 'ERROR') || e=$(printf '%s\n' "$1" | grep -v '^$' | tail -1)
    printf '%s' "$e" | cut -c1-160
}

# run_one <name> <path> <kind> <payload-sha> <expected-single-name>
# Fills L_RC T_RC X_RC TYPES VERDICT DETAIL NOTE.
run_one() {
    local name=$1 path=$2 kind=$3 psha=$4 want_name=$5
    local outdir inner l_out t_out x_out
    outdir=$(mktemp -d "$WORK/x.XXXXXX")
    sz l "$path"; L_RC=$RC; l_out=$OUT
    TYPES=$(printf '%s\n' "$OUT" | grep '^Type = ' | sed 's/^Type = //' | paste -sd+)
    sz t "$path"; T_RC=$RC; t_out=$OUT
    sz x "$path" "-o$outdir" -y; X_RC=$RC; x_out=$OUT
    log_out "l (rc=$L_RC)" "$name" "$l_out"; log_out "t (rc=$T_RC)" "$name" "$t_out"; log_out "x (rc=$X_RC)" "$name" "$x_out"
    NOTE=
    case $TYPES in *+tar) # chain: the tar members must be listed directly (drill-down)
        local marker=text512k.txt
        [ "$kind" = sparse ] && marker=sparse.bin
        if printf '%s\n' "$l_out" | grep -qF "$marker"; then NOTE="drill-down: members listed"; else NOTE="drill-down: NO (members not listed)"; fi ;;
    *) # a corpus/sparse vector named *.tar.* must be recognised as a chain
        if [ "$kind" != single ] && [ "$L_RC" -eq 0 ]; then
            case ${path##*/} in *.tar.*) NOTE="drill-down: NO (Type \"$TYPES\" has no +tar)" ;; esac
        fi ;;
    esac
    if [ "$X_RC" -ne 0 ] || [ "$T_RC" -ne 0 ] || [ "$L_RC" -ne 0 ]; then
        local all unclean=0 c
        all="$l_out"$'\n'"$t_out"$'\n'"$x_out"
        printf '%s\n' "$all" | grep -qE 'Unspecified|exception|Access violation|Segmentation' && unclean=1
        for c in "$L_RC" "$T_RC" "$X_RC"; do
            case $c in 0|1|2|7|8|255) ;; *) unclean=1 ;; esac
        done
        VERDICT=$([ "$unclean" -eq 1 ] && echo REJECTED-UNCLEAN || echo ERROR-EXIT)
        DETAIL=$(first_error "$all")
        return
    fi
    # one-step chains should land the members directly; if only a .tar came out, unpack it too
    local -a made=()
    mapfile -d '' -t made < <(find "$outdir" -type f -print0)
    if [ "${#made[@]}" -eq 1 ] && [ "${made[0]##*.}" = tar ] && [ "$kind" != single ]; then
        inner=$(mktemp -d "$WORK/xi.XXXXXX")
        if "$SZ" x "${made[0]}" "-o$inner" -y > /dev/null 2>&1; then outdir=$inner; NOTE="$NOTE; two-step (.tar came out first)"; fi
    fi
    check_output "$kind" "$outdir" "$psha" "$want_name"
    case $NOTE in
        *"drill-down: NO"*)
            VERDICT=FAIL; DETAIL="${DETAIL:+$DETAIL; }tar members were not listed by 7zz l (no drill-down)" ;;
    esac
}

# ---------------------------------------------------------------------------
# section: Windows artifacts
# ---------------------------------------------------------------------------

section_windows() {
    local n_win; n_win=$(find "$IOP/windows" -type f | wc -l)
    echo "### Windows 產物 $n_win 個"
    echo
    echo "| 檔案 | 類型（7zz l） | t | x | sha256 | 判定 | 與預期（全部 PASS）相同？ | 備註 |"
    echo "|---|---|---|---|---|---|---|---|"
    local f rel kind psha base nrows=0 npass=0
    local text_sha=${EXP_CORPUS["text512k.txt"]}
    while IFS= read -r f; do
        rel=${f#"$IOP/windows/"}
        case $rel in
            single/*) kind=single; psha=$text_sha ;;
            *) kind=corpus; psha= ;;
        esac
        run_one "windows/$rel" "$f" "$kind" "$psha" "$([ "$kind" = single ] && echo text512k.txt)"
        local shaword
        case $VERDICT in PASS) shaword="相符 ($([ "$kind" = single ] && echo 1/1 || echo "$N_CORPUS/$N_CORPUS"))" ;; *) shaword="不符／未解出" ;; esac
        local meth=
        case $rel in 7z/*) meth="; Method=$("$SZ" l -slt "$f" 2>&1 | grep -E '^Method = .+' | sed 's/^Method = //' | sort -u | paste -sd,)" ;; esac
        printf '| `%s` | %s | %s | %s | %s | %s | %s | %s |\n' "$rel" "$TYPES" "$T_RC" "$X_RC" "$shaword" "$VERDICT" "$([ "$VERDICT" = PASS ] && echo 同 || echo '**不同**')" "$(printf '%s' "$NOTE$meth ${DETAIL:+[$DETAIL]}" | sed 's/^; //' | sed 's/|/\\|/g')"
        nrows=$((nrows + 1)); N_ROWS=$((N_ROWS + 1))
        if [ "$VERDICT" = PASS ]; then npass=$((npass + 1)); else BAD_RUNS=$((BAD_RUNS + 1)); fi
    done < <(find "$IOP/windows" -type f | sort)
    echo
    echo "windows summary: $npass/$nrows PASS"
    echo
}

# ---------------------------------------------------------------------------
# section: Linux vectors
# ---------------------------------------------------------------------------

section_linux() {
    local lin=$IOP/linux manifest=$LINUX_MANIFEST
    local n_vec; n_vec=$(grep -cE '^\| `' "$manifest")
    echo "### Linux 向量 $n_vec 個"
    echo
    # transport check, and the vector set must equal what the manifest lists
    local sums_out sums_ok sums_bad
    sums_out=$(cd "$lin" && sha256sum -c SHA256SUMS 2>&1)
    sums_ok=$(printf '%s\n' "$sums_out" | grep -c ': OK$')
    sums_bad=$(printf '%s\n' "$sums_out" | grep -vc ': OK$')
    echo "linux/SHA256SUMS 核對：$sums_ok 個 OK、$sums_bad 個非 OK"
    [ "$sums_bad" -eq 0 ] || { printf '%s\n' "$sums_out" | grep -v ': OK$' | sed 's/^/  /'; BAD_RUNS=$((BAD_RUNS + 1)); }
    local listed on_disk set_diff
    listed=$(grep -E '^\| `' "$manifest" | sed -E 's/^\| `([^`]+)`.*/\1/' | sort)
    on_disk=$(cd "$lin" && find . -type f -printf '%P\n' | grep -vxF -e MANIFEST.md -e SHA256SUMS | sort)
    set_diff=$(diff <(printf '%s\n' "$listed") <(printf '%s\n' "$on_disk") | grep '^[<>]')
    if [ -n "$set_diff" ]; then
        echo "linux/ 檔案集合與 MANIFEST.md 不一致（< 只在 manifest、> 只在磁碟）："
        printf '%s\n' "$set_diff" | sed 's/^/  /'
        BAD_RUNS=$((BAD_RUNS + 1))
    else
        echo "linux/ 檔案集合與 MANIFEST.md 一致：$n_vec 個"
    fi
    echo
    echo "| 檔案 | 類型（7zz l） | t | x | sha256 | Windows 預期 | 本次判定 | 與 Windows 相同？ | 備註 |"
    echo "|---|---|---|---|---|---|---|---|---|"
    local line name path kind psha want_name win n=0 same=0
    declare -A counts=()
    while IFS= read -r line; do
        name=$(printf '%s' "$line" | sed -E 's/^\| `([^`]+)`.*/\1/')
        path=$lin/$name
        [ -f "$path" ] || { echo "| \`$name\` | - | - | - | - | - | MISSING | **不同** | 檔案不存在 |"; BAD_RUNS=$((BAD_RUNS + 1)); continue; }
        psha=$(printf '%s' "$line" | grep -oP 'sha256 `\K[0-9a-f]{64}' | head -1)
        want_name=
        case $name in
            tar/sparse.*) kind=sparse ;;
            tar/corpus.*|brotli/corpus.gnutar.tar.br) kind=corpus ;;
            *) kind=single; want_name=$(basename "$name"); want_name=${want_name%.*} ;;
        esac
        run_one "linux/$name" "$path" "$kind" "$psha" "$want_name"
        # a rejected vector: 7zz exits non-zero everywhere.  Classify like
        # Test-Interop.ps1: an expected rejection with an ordinary exit is clean.
        local v=$VERDICT
        win=${WIN_EXPECT[$name]:-PASS}
        if [ "$v" = ERROR-EXIT ]; then
            if [ "$win" = REJECTED-CLEAN ]; then v=REJECTED-CLEAN; else v=FAIL; fi
        elif [ "$v" = PASS ] && [ "$win" = REJECTED-CLEAN ]; then
            v=UNEXPECTED-OK
        fi
        local shaword
        case $v in
            PASS) shaword="相符" ;;
            UPSTREAM-LIMIT) shaword="相符（sparse 條目未展開）" ;;
            REJECTED-CLEAN) shaword="n/a（拒絕）" ;;
            *) shaword="不符／未解出" ;;
        esac
        local cmp="同"
        if [ "$v" = "$win" ]; then same=$((same + 1)); else cmp="**不同**"; BAD_RUNS=$((BAD_RUNS + 1)); fi
        counts[$v]=$(( ${counts[$v]:-0} + 1 ))
        n=$((n + 1)); N_ROWS=$((N_ROWS + 1))
        printf '| `%s` | %s | %s | %s | %s | %s | %s | %s | %s |\n' "$name" "$TYPES" "$T_RC" "$X_RC" "$shaword" "$win" "$v" "$cmp" "$(printf '%s' "$NOTE ${DETAIL:+[$DETAIL]}" | sed 's/^; //; s/|/\\|/g')"
    done < <(grep -E '^\| `' "$manifest")
    echo
    local k s=
    for k in "${!counts[@]}"; do s="$s $k=${counts[$k]}"; done
    echo "linux summary: $n vectors;$s; same-as-Windows $same/$n"
    echo
}

# ---------------------------------------------------------------------------
# section: apt tools both ways
# ---------------------------------------------------------------------------

APT_ROWS=0
disp() { local x=${1//@F@/FILE}; printf '%s' "${x//@D@/DIR}"; }
apt_row() { # <direction> <what> <result> <note>
    printf '| %s | %s | %s | %s |\n' "$1" "$(printf '%s' "$2" | sed 's/|/\\|/g')" "$3" "$(printf '%s' "$4" | sed 's/|/\\|/g' | cut -c1-200)"
    APT_ROWS=$((APT_ROWS + 1)); N_ROWS=$((N_ROWS + 1))
    [ "$3" = PASS ] || [ "$3" = UPSTREAM-LIMIT ] || BAD_RUNS=$((BAD_RUNS + 1))
}

section_apt() {
    local a=$WORK/apt
    mkdir -p "$a/in"
    cp -a "$CORPUS/." "$a/in/corpus/" 2>/dev/null || { mkdir -p "$a/in/corpus"; cp -a "$CORPUS/." "$a/in/corpus"; }
    # a mixed 4+ MiB single file: several zstd/lz4/brotli blocks
    local i
    for i in 1 2 3 4 5 6 7 8; do cat "$CORPUS/text512k.txt"; done > "$a/in/big.dat"
    cat "$CORPUS/random.bin" "$CORPUS/random.bin" "$CORPUS/random.bin" >> "$a/in/big.dat"
    local bigsha; bigsha=$(sha "$a/in/big.dat")

    echo "### apt 互解"
    echo
    echo "工具：zstd $(zstd --version | grep -o 'v[0-9][0-9.]*' | head -1)；brotli $(brotli --version | grep -o '[0-9][0-9.]*' | head -1)；lz4 $(lz4 --version | grep -o 'v[0-9][0-9.]*' | head -1)；$(tar --version | head -1)；$(bsdtar --version | cut -d' ' -f1-2)"
    echo "單檔 payload \`big.dat\`（$(stat -c %s "$a/in/big.dat") bytes，sha256 ${bigsha:0:16}…）；tar 類 payload 為 corpus/（$N_CORPUS 個檔）。"
    echo
    echo "| 方向 | 內容 | 結果 | 備註 |"
    echo "|---|---|---|---|"

    # ---- 7zz writes, CLI reads: single files -------------------------------
    local d got
    d=$a/w1; mkdir -p "$d"
    local fmt ext cli
    for spec in "zstd:zst:zstd -dc" "brotli:br:brotli -dc" "lz4:lz4:lz4 -dc"; do
        fmt=${spec%%:*}; ext=$(echo "$spec" | cut -d: -f2); cli=${spec#*:*:}
        (cd "$a/in" && "$SZ" a "-t$fmt" "$d/big.dat.$ext" big.dat > /dev/null 2>&1); local arc_rc=$?
        if [ "$arc_rc" -ne 0 ]; then apt_row "7zz → CLI" "-t$fmt → \`$cli\`" FAIL "7zz a rc=$arc_rc"; continue; fi
        got=$($cli "$d/big.dat.$ext" 2> "$d/err.$ext" | sha256sum | cut -d' ' -f1)
        if [ "$got" = "$bigsha" ]; then apt_row "7zz → CLI" "\`7zz a -t$fmt\` → \`$cli\`" PASS "sha256 相符，head=$(od -An -tx1 -N4 "$d/big.dat.$ext" | tr -d ' \n')"
        else apt_row "7zz → CLI" "\`7zz a -t$fmt\` → \`$cli\`" FAIL "sha256 $got；$(head -c 120 "$d/err.$ext")"; fi
    done
    # integrity-test modes of the CLIs as well
    zstd -t -q "$d/big.dat.zst" 2>&1 && apt_row "7zz → CLI" "\`7zz a -tzstd\` → \`zstd -t\`" PASS "" || apt_row "7zz → CLI" "\`7zz a -tzstd\` → \`zstd -t\`" FAIL ""
    brotli -t "$d/big.dat.br" 2>&1 && apt_row "7zz → CLI" "\`7zz a -tbrotli\` → \`brotli -t\`" PASS "" || apt_row "7zz → CLI" "\`7zz a -tbrotli\` → \`brotli -t\`" FAIL ""
    lz4 -t -q "$d/big.dat.lz4" 2>&1 && apt_row "7zz → CLI" "\`7zz a -tlz4\` → \`lz4 -t\`" PASS "" || apt_row "7zz → CLI" "\`7zz a -tlz4\` → \`lz4 -t\`" FAIL ""

    # ---- 7zz writes, CLI reads: tar chains ---------------------------------
    local ctr
    for ext in zst br lz4 gz xz bz2; do
        d=$a/w2-$ext; mkdir -p "$d"
        (cd "$a/in/corpus" && "$SZ" a "-ttar.$ext" "$d/corpus.tar.$ext" * > /dev/null 2>&1); local rc=$?
        if [ "$rc" -ne 0 ]; then apt_row "7zz → CLI" "-ttar.$ext" FAIL "7zz a rc=$rc"; continue; fi
        local -a readers=()
        case $ext in
            zst) readers=("zstd -dc @F@ | tar -xf - -C @D@" "tar --zstd -xf @F@ -C @D@" "tar -xf @F@ -C @D@" "bsdtar -xf @F@ -C @D@") ;;
            br)  readers=("brotli -dc @F@ | tar -xf - -C @D@" "tar -I brotli -xf @F@ -C @D@") ;;
            lz4) readers=("lz4 -dc @F@ | tar -xf - -C @D@" "tar -I lz4 -xf @F@ -C @D@" "bsdtar -xf @F@ -C @D@") ;;
            gz)  readers=("tar -xf @F@ -C @D@" "bsdtar -xf @F@ -C @D@") ;;
            xz)  readers=("tar -xf @F@ -C @D@" "bsdtar -xf @F@ -C @D@") ;;
            bz2) readers=("tar -xf @F@ -C @D@" "bsdtar -xf @F@ -C @D@") ;;
        esac
        for ctr in "${readers[@]}"; do
            local o=$d/out-$RANDOM; mkdir -p "$o"
            local cmd=${ctr//@F@/$d/corpus.tar.$ext}; cmd=${cmd//@D@/$o}
            if bash -c "set -o pipefail; $cmd" > /dev/null 2> "$d/err" ; then
                check_output corpus "$o" ""
                if [ "$VERDICT" = PASS ]; then apt_row "7zz → CLI" "\`7zz a -ttar.$ext\` → \`$(disp "$ctr")\`" PASS "$N_CORPUS/$N_CORPUS 相符"
                else apt_row "7zz → CLI" "\`7zz a -ttar.$ext\` → \`$(disp "$ctr")\`" "$VERDICT" "$DETAIL"; fi
            else
                apt_row "7zz → CLI" "\`7zz a -ttar.$ext\` → \`$(disp "$ctr")\`" FAIL "reader exit non-zero: $(head -c 150 "$d/err")"
            fi
        done
    done

    # ---- 7zz writes .7z, bsdtar reads --------------------------------------
    d=$a/w3; mkdir -p "$d"
    for m in zstd flzma2 lzma2; do
        (cd "$a/in/corpus" && "$SZ" a -t7z "-m0=$m" "$d/c-$m.7z" * > /dev/null 2>&1)
        local o=$d/out-$m; mkdir -p "$o"
        if bsdtar -xf "$d/c-$m.7z" -C "$o" > /dev/null 2> "$d/err"; then
            check_output corpus "$o" ""
            apt_row "7zz → CLI" "\`7zz a -t7z -m0=$m\` → \`bsdtar -xf\`" "$VERDICT" "${DETAIL:-$N_CORPUS/$N_CORPUS 相符}"
        else
            apt_row "7zz → CLI" "\`7zz a -t7z -m0=$m\` → \`bsdtar -xf\`" FAIL "$(head -c 150 "$d/err")"
        fi
    done

    # ---- CLI writes, 7zz reads: single files -------------------------------
    d=$a/r1; mkdir -p "$d"
    local -a mk=(
        "zstd -3~zstd -q -3 -c~zst"
        "zstd -19~zstd -q -19 -c~zst"
        "zstd --long=27~zstd -q --long=27 -c~zst"
        "zstd -T0 (stdin)~zstd -q -T0 -c~zst:stdin"
        "brotli -q 1~brotli -q 1 -c~br"
        "brotli -q 5~brotli -q 5 -c~br"
        "brotli -q 11 -w 24~brotli -q 11 -w 24 -c~br"
        "lz4 -1~lz4 -q -1 -c~lz4"
        "lz4 -9~lz4 -q -9 -c~lz4"
        "lz4 --content-size~lz4 -q --content-size -c~lz4"
        "lz4 -B7 -BD~lz4 -q -B7 -BD -c~lz4"
    )
    local spec desc enc ext2 o
    for spec in "${mk[@]}"; do
        desc=${spec%%~*}; enc=$(echo "$spec" | cut -d'~' -f2); ext2=$(echo "$spec" | cut -d'~' -f3)
        local stdin=0; case $ext2 in *:stdin) stdin=1; ext2=${ext2%%:*} ;; esac
        o=$d/$RANDOM; mkdir -p "$o"; cp /dev/null "$o/.keep"
        if [ "$stdin" -eq 1 ]; then $enc < "$a/in/big.dat" > "$o/big.dat.$ext2" 2> "$d/err"; else (cd "$a/in" && $enc big.dat > "$o/big.dat.$ext2" 2> "$d/err"); fi
        if [ ! -s "$o/big.dat.$ext2" ]; then apt_row "CLI → 7zz" "\`$desc\`" FAIL "encoder produced nothing: $(head -c 100 "$d/err")"; continue; fi
        sz t "$o/big.dat.$ext2"; local t_rc=$RC
        sz x "$o/big.dat.$ext2" "-o$o/x" -y; local x_rc=$RC
        if [ "$t_rc" -eq 0 ] && [ "$x_rc" -eq 0 ] && [ -f "$o/x/big.dat" ] && [ "$(sha "$o/x/big.dat")" = "$bigsha" ]; then
            apt_row "CLI → 7zz" "\`$desc\` → \`7zz t\`+\`x\`" PASS "t=0 x=0 sha256 相符"
        else
            apt_row "CLI → 7zz" "\`$desc\` → \`7zz t\`+\`x\`" FAIL "t=$t_rc x=$x_rc: $(first_error "$OUT")"
        fi
    done

    # ---- CLI writes tar chains, 7zz drills down ----------------------------
    d=$a/r2; mkdir -p "$d"
    local -a mkt=(
        "tar cf - | zstd~tar -C CORP -cf - -- . ~zstd -q~tar.zst"
        "tar --zstd -cf~tar -C CORP --zstd -cf OUT -- .~~tar.zst"
        "bsdtar --zstd -cf~bsdtar -C CORP --zstd -cf OUT .~~tar.zst"
        "tar cf - | brotli~tar -C CORP -cf - -- . ~brotli -q 5~tar.br"
        "tar cf - | lz4~tar -C CORP -cf - -- . ~lz4 -q~tar.lz4"
        "bsdtar --lz4 -cf~bsdtar -C CORP --lz4 -cf OUT .~~tar.lz4"
        "tar -czf~tar -C CORP -czf OUT -- .~~tar.gz"
        "tar -cJf~tar -C CORP -cJf OUT -- .~~tar.xz"
        "tar -cjf~tar -C CORP -cjf OUT -- .~~tar.bz2"
        "bsdtar -czf~bsdtar -C CORP -czf OUT .~~tar.gz"
    )
    for spec in "${mkt[@]}"; do
        desc=${spec%%~*}
        local mkcmd pipe2 ext3
        mkcmd=$(echo "$spec" | cut -d'~' -f2); pipe2=$(echo "$spec" | cut -d'~' -f3); ext3=$(echo "$spec" | cut -d'~' -f4)
        o=$d/$RANDOM; mkdir -p "$o"
        local out=$o/corpus.$ext3
        mkcmd=${mkcmd//CORP/$a/in/corpus}; mkcmd=${mkcmd//OUT/$out}
        if [ -n "$pipe2" ]; then bash -c "set -o pipefail; $mkcmd | $pipe2 > '$out'" 2> "$d/err"; else bash -c "$mkcmd" 2> "$d/err"; fi
        if [ ! -s "$out" ]; then apt_row "CLI → 7zz" "\`$desc\`" FAIL "encoder produced nothing: $(head -c 100 "$d/err")"; continue; fi
        run_one "apt/$desc" "$out" corpus "" ""
        local v=$VERDICT
        [ "$v" = ERROR-EXIT ] && v=FAIL
        apt_row "CLI → 7zz" "\`$desc\` → \`7zz l\`+\`t\`+\`x\`" "$v" "types=$TYPES t=$T_RC x=$X_RC; $NOTE ${DETAIL:+[$DETAIL]}"
    done
    echo
}

# ---------------------------------------------------------------------------

echo "7zz: $SZ"
echo "sha256: $(sha "$SZ")"
echo "locale: $LC_ALL"
echo
case $MODE in windows|all) section_windows ;; esac
case $MODE in linux|all) section_linux ;; esac
case $MODE in apt|all) section_apt ;; esac

echo "rows=$N_ROWS unexpected=$BAD_RUNS"
[ "$BAD_RUNS" -eq 0 ]

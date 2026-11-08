#!/bin/bash
# Compare size, sha256 and first 16 bytes of each windows/ file against MANIFEST.md rows.
# usage: check_headers.sh <interop-dir>
I="$1"
printf '%s\t%s\t%s\t%s\t%s\n' file size_ok sha_ok head_ok head_actual
grep -E '^\| `(single|chain|7z)/' "$I/MANIFEST.md" | while IFS='|' read -r _ f bytes head sha _; do
  f=${f//\`/}; f=${f// /}; bytes=${bytes// /}; sha=${sha//\`/}; sha=${sha// /}
  head=${head//\`/}; head=$(echo $head)
  p="$I/windows/$f"
  asz=$(stat -c %s "$p"); asha=$(sha256sum "$p" | cut -d' ' -f1)
  ahead=$(xxd -l 16 -p "$p" | tr 'a-f' 'A-F' | sed -E 's/(..)/\1 /g; s/ $//')
  [ "$asz" = "$bytes" ] && s=OK || s="NG(manifest=$bytes actual=$asz)"
  [ "$asha" = "$sha" ] && h=OK || h="NG"
  [ "$ahead" = "$head" ] && d=OK || d="NG(manifest=$head)"
  printf '%s\t%s\t%s\t%s\t%s\n' "$f" "$s" "$h" "$d" "$ahead"
done

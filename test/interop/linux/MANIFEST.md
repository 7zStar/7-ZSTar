# Interop fixtures - Linux side

由 `scripts/make_linux_vectors.sh` 在 Ubuntu 24.04.5 上產生，日期 2026-11-03。
工具版本見 `../REPORT.md` 第 1 節：zstd 1.5.5、brotli 1.1.0、lz4 1.9.4、GNU tar 1.35、bsdtar 3.7.2。
這批檔是給 7-ZSTar（Windows）回頭讀的。**每一個列出的檔，都已用寫出它的同一個工具解回來，並比對 sha256 全數相符**。解不回來的不列入（目前沒有）。

## 使用方式與符號

- `linux/` 底下所有檔以 `-text` 儲存，不做換行轉換，所以下表的 sha256 在各平台都成立。`SHA256SUMS`（本目錄）可用 `sha256sum -c` 核對傳輸是否完整。
- 「產生指令」在 `cwd` 欄指的目錄執行：`corpus` 是 `test/interop/corpus/`，`sparse-stage` 是下面「sparse 的額外 payload」建立的目錄。指令中的 `<out>` 是輸出檔，`<dir>` 是乾淨的解壓目錄，`<dir>/payload` 是單檔解碼結果。
- `tar/` 與 `brotli/corpus.gnutar.tar.br` 的 payload 是整個 `corpus/`，讀回後用 `sha256sum -c corpus/SHA256SUMS` 比對，滿分是 9 行全部 OK。其餘單檔向量的 payload 是 `text512k.txt`（sha256 `3b270f4fe7e0014485c9ff60248b5908111ce3d4cfd678b232e748baaac53e66`），例外者在備註欄寫明。
- 前 16 bytes 的判讀沿用 `../MANIFEST.md`：`28 B5 2F FD` 是 zstd frame，`04 22 4D 18` 是 LZ4 frame，`02 21 4C 18` 是 LZ4 legacy frame，`50 2A 4D 18` 是 skippable frame，brotli 沒有簽章。

## sparse 的額外 payload

`tar/sparse.*` 的 payload 是一個 4 MiB 的稀疏檔 `sparse.bin`，**不放進 repo**（解回來才有）。重建方式（在空目錄 `sparse-stage` 內執行）：

```bash
truncate -s 4M sparse.bin
printf 'HEAD'   | dd of=sparse.bin bs=1 seek=0       conv=notrunc status=none
printf 'MIDDLE' | dd of=sparse.bin bs=1 seek=2097152 conv=notrunc status=none
printf 'TAIL'   | dd of=sparse.bin bs=1 seek=4194300 conv=notrunc status=none
```

重建後的 `sparse.bin`：4194304 bytes，sha256 `81eb9bc536e525f810a56f46ae41e10af008fd8bc9200f8c57d86a9a554cdf80`。產生時它在檔案系統上只佔 24 blocks of 512 bytes，確實有洞。

## 向量

### 1 與 7. tar 與 tar 層變因

| 檔案 | 位元組 | 前 16 bytes | SHA-256 | cwd | 產生指令 | 解回驗證指令 | 驗證 | 備註 |
|---|---|---|---|---|---|---|---|---|
| `tar/corpus.gnutar-gnu.tar.zst` | 126209 | `28 B5 2F FD 04 58 B4 C9 04 FC 99 04 53 48 41 32` | `5ac636f3ccdb658f3ce5e7b29cbde81522e0feac171bfd899021417b14dd42f0` | `corpus` | `tar --zstd -cf <out> -- *` | `tar --zstd -xf <out> -C <dir>` | 通過 | 解出內容 9/9 sha256 相符（`corpus/SHA256SUMS`）；tar 方言：GNU（magic `ustar  `）；`@LongLink` 條目 1 個，PaxHeader 條目 0 個 |
| `tar/corpus.gnutar-pax.tar.zst` | 126565 | `28 B5 2F FD 04 58 EC 9F 04 9C 9D 04 2E 2F 50 61` | `b72f4f444655212d4bc324603397c2ef47ca2f90273286e49bb8817eb41af052` | `corpus` | `tar --format=pax --zstd -cf <out> -- *` | `tar --zstd -xf <out> -C <dir>` | 通過 | 解出內容 9/9 sha256 相符（`corpus/SHA256SUMS`）；tar 方言：POSIX／pax（magic `ustar` 加 `00`）；`@LongLink` 條目 0 個，PaxHeader 條目 11 個 |
| `tar/corpus.bsdtar-default.tar.zst` | 126394 | `28 B5 2F FD 00 58 B4 CA 04 BC 9B 04 53 48 41 32` | `ebd4492215b64bdc1b24300f0fb224c125a35fe1ef377f4b692bf660be0448d8` | `corpus` | `bsdtar --zstd -cf <out> -- *` | `bsdtar -xf <out> -C <dir>` | 通過 | 解出內容 9/9 sha256 相符（`corpus/SHA256SUMS`）；tar 方言：POSIX／pax（magic `ustar` 加 `00`）；`@LongLink` 條目 0 個，PaxHeader 條目 3 個 |
| `tar/corpus.bsdtar-gnutar.tar.zst` | 126213 | `28 B5 2F FD 00 58 F4 C9 04 7C 9A 04 53 48 41 32` | `77e6be2dc7451d6cfabc6796a6878e6115aa5d44258e769271390803e9dd0c96` | `corpus` | `bsdtar --format gnutar --zstd -cf <out> -- *` | `bsdtar -xf <out> -C <dir>` | 通過 | 解出內容 9/9 sha256 相符（`corpus/SHA256SUMS`）；tar 方言：GNU（magic `ustar  `）；`@LongLink` 條目 1 個，PaxHeader 條目 0 個 |
| `tar/corpus.bsdtar-default.tar.lz4` | 216863 | `04 22 4D 18 64 70 B9 0C 4F 03 00 BF 53 48 41 32` | `71480a2236a649a26751c4ae3411f70009e450ece1618af4bc4d7807e781384d` | `corpus` | `bsdtar --lz4 -cf <out> -- *` | `bsdtar -xf <out> -C <dir>` | 通過 | 解出內容 9/9 sha256 相符（`corpus/SHA256SUMS`）；tar 方言：POSIX／pax（magic `ustar` 加 `00`）；`@LongLink` 條目 0 個，PaxHeader 條目 3 個；標頭：FLG=0x64 BD=0x70：區塊獨立，區塊 checksum 無，content size 無，content checksum 有，最大區塊 4 MiB |
| `tar/sparse.gnutar-sparse-gnu.tar.zst` | 158 | `28 B5 2F FD 04 58 8D 04 00 C2 44 11 17 80 B5 3A` | `159c753e449d4bc900ceeeb196f32cab9f8855845c56dda3c35d461952dc31db` | `sparse-stage` | `tar --sparse --format=gnu --zstd -cf <out> sparse.bin` | `tar --zstd -xf <out> -C <dir>` | 通過 | 解出的 `sparse.bin` 必須是 4194304 bytes，sha256 `81eb9bc536e525f810a56f46ae41e10af008fd8bc9200f8c57d86a9a554cdf80`；第一個標頭 type=S（GNU 舊式 sparse）；解壓後 tar 共 20480 bytes |
| `tar/sparse.gnutar-sparse-pax.tar.zst` | 297 | `28 B5 2F FD 04 58 E5 08 00 12 0E 2C 22 30 89 56` | `4107eebbb47ebba6aab074e8abda1d04a5210d72e2f0f14be78ed9bfee2ae38d` | `sparse-stage` | `tar --sparse --format=pax --zstd -cf <out> sparse.bin` | `tar --zstd -xf <out> -C <dir>` | 通過 | 解出的 `sparse.bin` 必須是 4194304 bytes，sha256 `81eb9bc536e525f810a56f46ae41e10af008fd8bc9200f8c57d86a9a554cdf80`；含 4 個 `GNU.sparse` 鍵；解壓後 tar 共 20480 bytes |
| `tar/sparse.bsdtar-default.tar.zst` | 271 | `28 B5 2F FD 00 58 35 08 00 D2 0C 29 22 40 89 56` | `4e6712d839cb83a59b3c8c061371acaee27c6e3b1e9c1bf6b65492da588b3f44` | `sparse-stage` | `bsdtar --zstd -cf <out> sparse.bin` | `bsdtar -xf <out> -C <dir>` | 通過 | 解出的 `sparse.bin` 必須是 4194304 bytes，sha256 `81eb9bc536e525f810a56f46ae41e10af008fd8bc9200f8c57d86a9a554cdf80`；第一個標頭 type=x（pax extended header）；含 4 個 `GNU.sparse` 鍵；解壓後 tar 共 15360 bytes |

### 2. zstd 單檔

| 檔案 | 位元組 | 前 16 bytes | SHA-256 | cwd | 產生指令 | 解回驗證指令 | 驗證 | 備註 |
|---|---|---|---|---|---|---|---|---|
| `zstd/zstd-19.text512k.txt.zst` | 76820 | `28 B5 2F FD A4 05 00 08 00 64 4C 00 A6 1B 44 1B` | `760ac5c2682efef04859440a4f94783422c0cbd8631cb55b2658b7801f4d9007` | `corpus` | `zstd -19 -q -f -o <out> text512k.txt` | `zstd -d -q -f -o <dir>/payload <out>` | 通過 | 解碼後必須等於 text512k.txt，sha256 `3b270f4fe7e0014485c9ff60248b5908111ce3d4cfd678b232e748baaac53e66`；zstd -lv：Zstandard Frames: 1；Window Size: 512 KiB (524293 B)；Decompressed Size: 512 KiB (524293 B)；Check: XXH64 a1600fe8 |
| `zstd/zstd-T0-long31.text512k.txt.zst` | 103210 | `28 B5 2F FD A4 05 00 08 00 AC 2D 03 9A 64 84 0D` | `eb17cf7b2ac07e4bbb229a1fc601263146504db48243cafdb996cdb24a95f29a` | `corpus` | `zstd -T0 --long=31 -q -f -o <out> text512k.txt` | `zstd -d --long=31 -q -f -o <dir>/payload <out>` | 通過 | 解碼後必須等於 text512k.txt，sha256 `3b270f4fe7e0014485c9ff60248b5908111ce3d4cfd678b232e748baaac53e66`；zstd -lv：Zstandard Frames: 1；Window Size: 512 KiB (524293 B)；Decompressed Size: 512 KiB (524293 B)；Check: XXH64 a1600fe8；檔案輸入時 zstd 把視窗收斂成 512 KiB，**不是**真正的長視窗；要測 2 GiB 視窗請用 stdin 那一個 |
| `zstd/zstd-T0-long31-stdin.text512k.txt.zst` | 103207 | `28 B5 2F FD 04 A8 AC 2D 03 9A 64 84 0D 1C 70 49` | `82abc9589f648705cd90257fc7e540a214044605205c22f757314d34108b1bfb` | `corpus` | `cat text512k.txt \| zstd -T0 --long=31 -q > <out>` | `zstd -d --long=31 -q -f -o <dir>/payload <out>` | 通過 | 解碼後必須等於 text512k.txt，sha256 `3b270f4fe7e0014485c9ff60248b5908111ce3d4cfd678b232e748baaac53e66`；zstd -lv：Zstandard Frames: 1；Window Size: 2.00 GiB (2147483648 B)；Check: XXH64 a1600fe8；實測：不加 `--long=31` 的 `zstd -d` 拒絕解碼，exit 1，訊息 `Window size larger than maximum : 2147483648 > 134217728` |
| `zstd/zstd-no-check.text512k.txt.zst` | 103206 | `28 B5 2F FD A0 05 00 08 00 AC 2D 03 9A 64 84 0D` | `4f5d6f05bf737436640ffe1dcdbbf4309de42a7577af0a339f083bbe226239ce` | `corpus` | `zstd --no-check -q -f -o <out> text512k.txt` | `zstd -d -q -f -o <dir>/payload <out>` | 通過 | 解碼後必須等於 text512k.txt，sha256 `3b270f4fe7e0014485c9ff60248b5908111ce3d4cfd678b232e748baaac53e66`；zstd -lv：Zstandard Frames: 1；Window Size: 512 KiB (524293 B)；Decompressed Size: 512 KiB (524293 B)；Check: None |
| `zstd/zstd-no-content-size.text512k.txt.zst` | 103207 | `28 B5 2F FD 04 50 AC 2D 03 9A 64 84 0D 1C 70 49` | `cbca7463d00eb48eb13c3c6811e4b287193533a1bdecefbd7d9bb70107c4f7fa` | `corpus` | `zstd --no-content-size -q -f -o <out> text512k.txt` | `zstd -d -q -f -o <dir>/payload <out>` | 通過 | 解碼後必須等於 text512k.txt，sha256 `3b270f4fe7e0014485c9ff60248b5908111ce3d4cfd678b232e748baaac53e66`；zstd -lv：Zstandard Frames: 1；Window Size: 1.000 MiB (1048576 B)；Check: XXH64 a1600fe8 |
| `zstd/zstd-stdin.text512k.txt.zst` | 103207 | `28 B5 2F FD 04 58 AC 2D 03 9A 64 84 0D 1C 70 49` | `1d1d9d9b9d16abb8f1a3f3dd44f0c158ad2cc686e0ef4a75466393ba906eb8ba` | `corpus` | `cat text512k.txt \| zstd -q > <out>` | `zstd -d -q -f -o <dir>/payload <out>` | 通過 | 解碼後必須等於 text512k.txt，sha256 `3b270f4fe7e0014485c9ff60248b5908111ce3d4cfd678b232e748baaac53e66`；zstd -lv：Zstandard Frames: 1；Window Size: 2.00 MiB (2097152 B)；Check: XXH64 a1600fe8 |

### 3. 多 frame 與 skippable frame

| 檔案 | 位元組 | 前 16 bytes | SHA-256 | cwd | 產生指令 | 解回驗證指令 | 驗證 | 備註 |
|---|---|---|---|---|---|---|---|---|
| `zstd-frames/concat.a-then-b.zst` | 4489 | `28 B5 2F FD 64 47 4D BD 83 00 B6 E4 5E 1B 90 27` | `93743674e9c7ddd853ac21db7536a9dde81767e531411248c541e717130e7bb0` | `corpus` | `T=$(mktemp -d); zstd -q -c a.txt > $T/A.zst; zstd -q -c b-crlf.txt > $T/B.zst; cat $T/A.zst $T/B.zst > <out>` | `zstd -d -q -c <out> > <dir>/payload` | 通過 | 解碼後必須等於 a.txt 接 b-crlf.txt，sha256 `612563d3f347c0ef8201b9132542c093050a585ebe78e28cdde782d874b7f494`；zstd -lv：Zstandard Frames: 2；Window Size: 4.58 KiB (4692 B)；Decompressed Size: 24.2 KiB (24731 B)；Check: XXH64；兩個獨立 zstd frame 直接串接（a.txt 的 frame 在前，b-crlf.txt 的在後） |
| `zstd-frames/skippable-before.a.zst` | 4253 | `50 2A 4D 18 10 00 00 00 30 31 32 33 34 35 36 37` | `5fba47c1570891b2d7e4fc131320fbf17cd881f04447afc6bb601c56fe5addbb` | `corpus` | `T=$(mktemp -d); zstd -q -c a.txt > $T/A.zst; { printf '\x50\x2a\x4d\x18\x10\x00\x00\x00'; printf '0123456789ABCDEF'; cat $T/A.zst; } > <out>` | `zstd -d -q -c <out> > <dir>/payload` | 通過 | 解碼後必須等於 a.txt，sha256 `a5881b53cb1844c4e5d1de26a28774c9b9e1ada64b8636cad38b5299670fd4e1`；zstd -lv：Zstandard Frames: 1；Skippable Frames: 1；Window Size: 19.6 KiB (20039 B)；Decompressed Size: 19.6 KiB (20039 B)；Check: XXH64 c583da58；手工 skippable frame：魔數 `50 2A 4D 18`，長度 16（little-endian `10 00 00 00`），內容 ASCII `0123456789ABCDEF` |
| `zstd-frames/skippable-between.a-b.zst` | 4513 | `28 B5 2F FD 64 47 4D BD 83 00 B6 E4 5E 1B 90 27` | `01f61ee02f811270306125b4324de2b6ee54e62e3ed4bcbd501c1f364cc87884` | `corpus` | `T=$(mktemp -d); zstd -q -c a.txt > $T/A.zst; zstd -q -c b-crlf.txt > $T/B.zst; { cat $T/A.zst; printf '\x50\x2a\x4d\x18\x10\x00\x00\x00'; printf '0123456789ABCDEF'; cat $T/B.zst; } > <out>` | `zstd -d -q -c <out> > <dir>/payload` | 通過 | 解碼後必須等於 a.txt 接 b-crlf.txt，sha256 `612563d3f347c0ef8201b9132542c093050a585ebe78e28cdde782d874b7f494`；zstd -lv：Zstandard Frames: 2；Skippable Frames: 1；Window Size: 4.58 KiB (4692 B)；Decompressed Size: 24.2 KiB (24731 B)；Check: XXH64；手工 skippable frame：魔數 `50 2A 4D 18`，長度 16（little-endian `10 00 00 00`），內容 ASCII `0123456789ABCDEF` |

### 5. brotli

| 檔案 | 位元組 | 前 16 bytes | SHA-256 | cwd | 產生指令 | 解回驗證指令 | 驗證 | 備註 |
|---|---|---|---|---|---|---|---|---|
| `brotli/brotli-q0-w10.text512k.txt.br` | 212427 | `83 FF 01 00 80 AA AA AA EA FF 6E 97 13 1F 8E E2` | `3cb19c80f115870537812f5cdb35d3eebe53bcc67c590eafae356a2230fe39ea` | `corpus` | `brotli -q 0 -w 10 -c text512k.txt > <out>` | `brotli -d -c <out> > <dir>/payload` | 通過 | 解碼後必須等於 text512k.txt，sha256 `3b270f4fe7e0014485c9ff60248b5908111ce3d4cfd678b232e748baaac53e66`；檔頭解出 WBITS=18，與要求的 `-w 10` 不同 |
| `brotli/brotli-q0-w24.text512k.txt.br` | 131047 | `AF FF FF 03 00 A8 AA AA AA FE 67 ED 99 B1 E9 E9` | `828180b05de01b851b5c22c24c8ff62db5e5473865180b2cf6c949d93069ebe3` | `corpus` | `brotli -q 0 -w 24 -c text512k.txt > <out>` | `brotli -d -c <out> > <dir>/payload` | 通過 | 解碼後必須等於 text512k.txt，sha256 `3b270f4fe7e0014485c9ff60248b5908111ce3d4cfd678b232e748baaac53e66`；檔頭解出 WBITS=24 |
| `brotli/brotli-q5-w16.text512k.txt.br` | 98476 | `F4 FF 1F 88 A8 EC F5 70 40 11 32 CC 6D D9 F2 3F` | `8317fb540094742dc9054c3779a2d095de7e0da905a79b2cf02ef4054c196fd7` | `corpus` | `brotli -q 5 -w 16 -c text512k.txt > <out>` | `brotli -d -c <out> > <dir>/payload` | 通過 | 解碼後必須等於 text512k.txt，sha256 `3b270f4fe7e0014485c9ff60248b5908111ce3d4cfd678b232e748baaac53e66`；檔頭解出 WBITS=16 |
| `brotli/brotli-q5-w22.text512k.txt.br` | 98446 | `5B 04 00 48 44 65 B3 87 03 8A 90 61 6E CB EC E9` | `719fe838c575925958e2dbb40ed2d0404a7ad78341408f1fbdc57cfd46fe6136` | `corpus` | `brotli -q 5 -w 22 -c text512k.txt > <out>` | `brotli -d -c <out> > <dir>/payload` | 通過 | 解碼後必須等於 text512k.txt，sha256 `3b270f4fe7e0014485c9ff60248b5908111ce3d4cfd678b232e748baaac53e66`；檔頭解出 WBITS=22 |
| `brotli/brotli-q11-w10.text512k.txt.br` | 98307 | `21 FD FF 07 10 56 C9 E3 D4 2F 61 2E 26 0A 3B 34` | `ee8d374e5435f94f6af47a788ba9df043abf2a43f1dfe82365610d5109d51a2f` | `corpus` | `brotli -q 11 -w 10 -c text512k.txt > <out>` | `brotli -d -c <out> > <dir>/payload` | 通過 | 解碼後必須等於 text512k.txt，sha256 `3b270f4fe7e0014485c9ff60248b5908111ce3d4cfd678b232e748baaac53e66`；檔頭解出 WBITS=10 |
| `brotli/brotli-q11-w16.text512k.txt.br` | 79135 | `F4 FF 1F 22 2A 56 B9 11 49 68 AF 6B 66 54 D8 38` | `64545a2314b80caf24edb06d87d804a37dee3f0ac5e4499816a868f4d465b6cb` | `corpus` | `brotli -q 11 -w 16 -c text512k.txt > <out>` | `brotli -d -c <out> > <dir>/payload` | 通過 | 解碼後必須等於 text512k.txt，sha256 `3b270f4fe7e0014485c9ff60248b5908111ce3d4cfd678b232e748baaac53e66`；檔頭解出 WBITS=16 |
| `brotli/brotli-q11-w22.text512k.txt.br` | 76857 | `5B 04 00 18 51 D1 4B 41 11 69 34 2D 06 15 19 10` | `6a8cb7b541aadb2be068d5138ed6224f3e9e6e0d95cb2e76b4119ba4427a6ab9` | `corpus` | `brotli -q 11 -w 22 -c text512k.txt > <out>` | `brotli -d -c <out> > <dir>/payload` | 通過 | 解碼後必須等於 text512k.txt，sha256 `3b270f4fe7e0014485c9ff60248b5908111ce3d4cfd678b232e748baaac53e66`；檔頭解出 WBITS=22 |
| `brotli/brotli-q11-w24.text512k.txt.br` | 76857 | `5F 04 00 18 51 D1 4B 41 11 69 34 2D 06 15 19 10` | `01d2971f44a1601abe68dd499e23c83e8305635b5e423c6a5e4fc44a303fa725` | `corpus` | `brotli -q 11 -w 24 -c text512k.txt > <out>` | `brotli -d -c <out> > <dir>/payload` | 通過 | 解碼後必須等於 text512k.txt，sha256 `3b270f4fe7e0014485c9ff60248b5908111ce3d4cfd678b232e748baaac53e66`；檔頭解出 WBITS=24 |
| `brotli/corpus.gnutar.tar.br` | 97230 | `9F FF D7 18 33 A3 36 99 17 93 BA 82 1D F3 C1 ED` | `170677c7507010ef5fe95cc54af608f304aeaa2e2fbdce13c5aca44da7319adf` | `corpus` | `tar cf - -- * \| brotli -c > <out>` | `brotli -d -c <out> \| tar -xf - -C <dir>` | 通過 | 解出內容 9/9 sha256 相符；由 `tar cf -` 串流壓縮，沒有 content size；檔頭解出 WBITS=24 |
| `brotli/brotli-q5-large-window30.text512k.txt.br` | 98448 | `11 5E 11 00 20 11 95 CD 1E 0E 28 42 86 B9 2D B3` | `b5ea7f708d2b60a9adde34385ad66a5d8021aab67aca18511c18db6eae70c45b` | `corpus` | `brotli -q 5 --large_window=30 -c text512k.txt > <out>` | `brotli -d --large_window=30 -c <out> > <dir>/payload` | 通過 | 解碼後必須等於 text512k.txt，sha256 `3b270f4fe7e0014485c9ff60248b5908111ce3d4cfd678b232e748baaac53e66`；檔頭解出 WBITS=30（大視窗位元流，首位元組 0x11）；實測：不加 `--large_window` 的 `brotli -d` 也能解（exit 0，sha256 相符）。事前預期 7-ZSTar 讀不了，要看的是錯誤是否乾淨 |

### 4 與 6. lz4（含 `zstd --format=lz4`）

| 檔案 | 位元組 | 前 16 bytes | SHA-256 | cwd | 產生指令 | 解回驗證指令 | 驗證 | 備註 |
|---|---|---|---|---|---|---|---|---|
| `lz4/zstd-format-lz4.text512k.txt.lz4` | 127952 | `04 22 4D 18 4C 40 05 00 08 00 00 00 00 00 2F A0` | `2bb43aa776b50d9f9120fa374c26bb1da93ced30fb7ed29ff51c46c1ca1664c1` | `corpus` | `zstd --format=lz4 -q -f -o <out> text512k.txt` | `zstd -d -q -f -o <dir>/payload <out>` | 通過 | 解碼後必須等於 text512k.txt，sha256 `3b270f4fe7e0014485c9ff60248b5908111ce3d4cfd678b232e748baaac53e66`；標頭：FLG=0x4C BD=0x40：區塊相依（linked），區塊 checksum 無，content size 有，content checksum 有，最大區塊 64 KiB；前 16 bytes 與 Windows 端 `single/text512k.txt.lz4` 相同 |
| `lz4/lz4-B4.text512k.txt.lz4` | 208923 | `04 22 4D 18 64 40 A7 09 66 00 00 61 6C 69 6E 65` | `ade7800ad065bab4ed93488fc237fe2d5ab928042ab31d00e1ff95d919ac9d32` | `corpus` | `lz4 -q -f -B4 text512k.txt <out>` | `lz4 -d -q -f <out> <dir>/payload` | 通過 | 解碼後必須等於 text512k.txt，sha256 `3b270f4fe7e0014485c9ff60248b5908111ce3d4cfd678b232e748baaac53e66`；標頭：FLG=0x64 BD=0x40：區塊獨立，區塊 checksum 無，content size 無，content checksum 有，最大區塊 64 KiB |
| `lz4/lz4-B7.text512k.txt.lz4` | 190545 | `04 22 4D 18 64 60 85 3E E8 02 00 61 6C 69 6E 65` | `d673c4e1859095424acd499c10ba989e2453b4ac45be86a56d1f89918347ac17` | `corpus` | `lz4 -q -f -B7 text512k.txt <out>` | `lz4 -d -q -f <out> <dir>/payload` | 通過 | 解碼後必須等於 text512k.txt，sha256 `3b270f4fe7e0014485c9ff60248b5908111ce3d4cfd678b232e748baaac53e66`；標頭：FLG=0x64 BD=0x60：區塊獨立，區塊 checksum 無，content size 無，content checksum 有，最大區塊 1 MiB；要求 `-B7`（4 MiB），標頭實為 1 MiB（輸入只有 512 KiB）；位元組與 `lz4/lz4-BD.text512k.txt.lz4` 完全相同 |
| `lz4/lz4-BD.text512k.txt.lz4` | 190545 | `04 22 4D 18 64 60 85 3E E8 02 00 61 6C 69 6E 65` | `d673c4e1859095424acd499c10ba989e2453b4ac45be86a56d1f89918347ac17` | `corpus` | `lz4 -q -f -BD text512k.txt <out>` | `lz4 -d -q -f <out> <dir>/payload` | 通過 | 解碼後必須等於 text512k.txt，sha256 `3b270f4fe7e0014485c9ff60248b5908111ce3d4cfd678b232e748baaac53e66`；標頭：FLG=0x64 BD=0x60：區塊獨立，區塊 checksum 無，content size 無，content checksum 有，最大區塊 1 MiB；位元組與 `lz4/lz4-B7.text512k.txt.lz4` 完全相同 |
| `lz4/lz4-BX.text512k.txt.lz4` | 190549 | `04 22 4D 18 74 60 D9 3E E8 02 00 61 6C 69 6E 65` | `88ac8c5b7739b8bb57d1a47134708243f46c44e0e65a90ef750e60c02c10df7c` | `corpus` | `lz4 -q -f -BX text512k.txt <out>` | `lz4 -d -q -f <out> <dir>/payload` | 通過 | 解碼後必須等於 text512k.txt，sha256 `3b270f4fe7e0014485c9ff60248b5908111ce3d4cfd678b232e748baaac53e66`；標頭：FLG=0x74 BD=0x60：區塊獨立，區塊 checksum 有，content size 無，content checksum 有，最大區塊 1 MiB |
| `lz4/lz4-no-frame-crc.text512k.txt.lz4` | 190541 | `04 22 4D 18 60 60 51 3E E8 02 00 61 6C 69 6E 65` | `4f83d6732d3cb5f79e5d75552587b6c2fab6cba1d83487ecf240799417707838` | `corpus` | `lz4 -q -f --no-frame-crc text512k.txt <out>` | `lz4 -d -q -f <out> <dir>/payload` | 通過 | 解碼後必須等於 text512k.txt，sha256 `3b270f4fe7e0014485c9ff60248b5908111ce3d4cfd678b232e748baaac53e66`；標頭：FLG=0x60 BD=0x60：區塊獨立，區塊 checksum 無，content size 無，content checksum 無，最大區塊 1 MiB |
| `lz4/lz4-content-size.text512k.txt.lz4` | 190553 | `04 22 4D 18 6C 60 05 00 08 00 00 00 00 00 6A 3E` | `458a526616665b8d44e5df12a75c82d7a7a66c85ca1dd41c970784da7738e672` | `corpus` | `lz4 -q -f --content-size text512k.txt <out>` | `lz4 -d -q -f <out> <dir>/payload` | 通過 | 解碼後必須等於 text512k.txt，sha256 `3b270f4fe7e0014485c9ff60248b5908111ce3d4cfd678b232e748baaac53e66`；標頭：FLG=0x6C BD=0x60：區塊獨立，區塊 checksum 無，content size 有，content checksum 有，最大區塊 1 MiB |
| `lz4/lz4-legacy.text512k.txt.lz4` | 190534 | `02 21 4C 18 3E E8 02 00 61 6C 69 6E 65 20 30 01` | `f4b12ea082dd6b25af637686c460a85e7fe99dc1352f9a087cbc6ae380a180e8` | `corpus` | `lz4 -q -f -l text512k.txt <out>` | `lz4 -d -q -f <out> <dir>/payload` | 通過 | 解碼後必須等於 text512k.txt，sha256 `3b270f4fe7e0014485c9ff60248b5908111ce3d4cfd678b232e748baaac53e66`；標頭：legacy frame（magic 02 21 4C 18）；事前預期 7-ZSTar 拒絕 legacy frame；要看的是錯誤是否乾淨 |
| `lz4/lz4-B4-BD.text512k.txt.lz4` | 190614 | `04 22 4D 18 44 40 5E E0 5D 00 00 61 6C 69 6E 65` | `87c2d057750659e689f6d2cc9d7ff16ab290c6fbcc657066b9728e206c81249d` | `corpus` | `lz4 -q -f -B4 -BD text512k.txt <out>` | `lz4 -d -q -f <out> <dir>/payload` | 通過 | 解碼後必須等於 text512k.txt，sha256 `3b270f4fe7e0014485c9ff60248b5908111ce3d4cfd678b232e748baaac53e66`；標頭：FLG=0x44 BD=0x40：區塊相依（linked），區塊 checksum 無，content size 無，content checksum 有，最大區塊 64 KiB |
| `lz4/concat.a-then-b.lz4` | 9056 | `04 22 4D 18 64 40 A7 3B 1F 00 00 61 6C 69 6E 65` | `f1257dadaa56115bc2e5fa4626c070c4dc799a0fa382bb78f3e583a89b064853` | `corpus` | `T=$(mktemp -d); lz4 -q -f a.txt $T/A.lz4; lz4 -q -f b-crlf.txt $T/B.lz4; cat $T/A.lz4 $T/B.lz4 > <out>` | `lz4 -d -q -f <out> <dir>/payload` | 通過 | 解碼後必須等於 a.txt 接 b-crlf.txt，sha256 `612563d3f347c0ef8201b9132542c093050a585ebe78e28cdde782d874b7f494`；標頭：FLG=0x64 BD=0x40：區塊獨立，區塊 checksum 無，content size 無，content checksum 有，最大區塊 64 KiB |

## 未產生的項目

| 項目 | 原因 |
|---|---|
| (lz5 vectors) | 未產生：Ubuntu 24.04 沒有 lz5 套件，依規定不從原始碼編譯 |
| (lizard vectors) | 未產生：Ubuntu 24.04 沒有 lizard 套件，依規定不從原始碼編譯 |

共 37 個向量，總計 4076124 bytes。

<#
.SYNOPSIS
    Generate the Windows side of the cross-platform interop fixtures.

.DESCRIPTION
    Writes test\interop\corpus (a fixed, reproducible payload) and
    test\interop\windows (archives of that payload produced by this tree's
    7z.exe in every format 7-ZSTar adds, plus a few upstream formats as a
    baseline), then test\interop\MANIFEST.md describing every file: the exact
    7z command, size, sha256 and the first 16 bytes. The first 16 bytes matter:
    they tell a reader whether a .lz4/.zst/.br is a plain frame or mcmilk's
    multi-threaded skippable-frame container, which decides what other tools
    can be expected to read.

    The Linux side (test\interop\linux, REPORT.md) is produced elsewhere; this
    script never touches it. Re-running regenerates corpus and windows from
    scratch. The corpus bytes are deterministic, but the archives embed file
    timestamps, so 18 of the 25 archives get new sha256 values on every run -
    and those values are what the Linux side's REPORT.md and matrix were
    checked against. Regenerating therefore invalidates that evidence, which
    is why an existing fixture set is only overwritten with -Force.

.PARAMETER Force
    Overwrite an existing test\interop\corpus and windows. Refused without it.

.PARAMETER Platform
    Build output to use (x64 by default).

.PARAMETER BinDir
    Directory holding 7z.exe. Defaults to the Console build output; 7z.dll is
    borrowed from the Format7zF bundle the same way Test-Smoke.ps1 does.

.PARAMETER OutDir
    Where test\interop lives. Defaults to <repo>\test\interop.
#>
#Requires -Version 7.2
[CmdletBinding()]
param(
    [ValidateSet('x64', 'x86', 'arm64')]
    [string]$Platform = 'x64',
    [string]$BinDir,
    [string]$OutDir,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path $PSScriptRoot -Parent
# .NET IO resolves relative paths against the process directory, cmdlets
# against PowerShell's location; absolute paths keep the two in agreement.
function Resolve-Full($p) { $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($p) }

# 7z.dll is borrowed from the build tree only for the default BinDir; a
# caller who points at a specific directory gets exactly what is there.
if ($PSBoundParameters.ContainsKey('BinDir')) {
    $BinDir = Resolve-Full $BinDir
} else {
    $BinDir = Join-Path $RepoRoot "CPP\7zip\UI\Console\$Platform"
    $dllSrc = Join-Path $RepoRoot "CPP\7zip\Bundles\Format7zF\$Platform\7z.dll"
    if (Test-Path $dllSrc) { Copy-Item $dllSrc (Join-Path $BinDir '7z.dll') -Force }
}
$SevenZip = Join-Path $BinDir '7z.exe'
if (-not (Test-Path $SevenZip)) { throw "7z.exe not found: $SevenZip" }
if (-not (Test-Path (Join-Path $BinDir '7z.dll'))) { throw "7z.dll not found next to $SevenZip" }

# Assert the banner before touching any output: this proves the binary runs
# on this machine and is 7-ZSTar, not whatever 7z.exe a PATH alias found.
$banner = (& $SevenZip 2>&1 | Select-Object -First 3 | Where-Object { $_ -match '7-ZSTar' } | Select-Object -First 1)
if (-not $banner) { throw "$SevenZip did not identify itself as 7-ZSTar (or failed to run)" }

$OutDir = $(if ($OutDir) { Resolve-Full $OutDir } else { Join-Path $RepoRoot 'test\interop' })
$Corpus = Join-Path $OutDir 'corpus'
$WinDir = Join-Path $OutDir 'windows'
$existing = @($Corpus, $WinDir | Where-Object { Test-Path $_ })
if ($existing.Count -gt 0) {
    # Refuse to delete anything that does not look like our own fixture set,
    # and even then only on request (see the Force note above).
    $marker = Join-Path $OutDir 'MANIFEST.md'
    $ours = (Test-Path $marker) -and ((Get-Content -LiteralPath $marker -TotalCount 1) -eq '# Interop fixtures - Windows side')
    if (-not $ours) { throw "$OutDir already has corpus/windows but no 7-ZSTar interop MANIFEST.md; refusing to delete" }
    if (-not $Force) { throw "$OutDir already holds a fixture set; regenerating changes the archive hashes the Linux-side evidence was checked against. Re-run with -Force to overwrite." }
    foreach ($d in $existing) { Remove-Item -LiteralPath $d -Recurse -Force }
}
foreach ($d in $Corpus, $WinDir) { New-Item -ItemType Directory -Force $d | Out-Null }

$Utf8 = [System.Text.UTF8Encoding]::new($false)
function Write-Bytes($path, [byte[]]$bytes) {
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    [System.IO.File]::WriteAllBytes($path, $bytes)
}
function Sha($path) { (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Head16($path) {
    $fs = [System.IO.File]::OpenRead($path)
    try {
        $buf = New-Object byte[] 16
        $n = $fs.Read($buf, 0, 16)
        return (($buf[0..([Math]::Max($n, 1) - 1)] | ForEach-Object { $_.ToString('X2') }) -join ' ')
    } finally { $fs.Dispose() }
}
# Same trick as Test-Smoke.ps1: a literal "-ttar.br" on the command line is
# mangled by PowerShell's parser; building the argument list as an array and
# splatting it keeps every switch intact.
function Sz {
    param([string[]]$SzArgs)
    $out = & $SevenZip @SzArgs 2>&1
    return @{ Out = ($out -join "`n"); Code = $LASTEXITCODE }
}

# ---------------------------------------------------------------------------
# Corpus: fixed content, so every archive below has a known expected payload.
# Only ASCII in this script; non-ASCII text is built from code points.
# ---------------------------------------------------------------------------
$rng = [System.Random]::new(20261104)
$words = @('zstd', 'brotli', 'lz4', 'lizard', 'tar', 'frame', 'block', 'window', 'stream',
           'archive', 'seven', 'zip', 'header', 'checksum', 'skippable', 'dictionary',
           'entropy', 'match', 'literal', 'offset')
function New-Text([int]$bytes, [string]$eol) {
    $sb = [System.Text.StringBuilder]::new()
    $line = 0
    while ($sb.Length -lt $bytes) {
        $n = 6 + $rng.Next(8)
        $ws = for ($i = 0; $i -lt $n; $i++) { $words[$rng.Next($words.Count)] }
        [void]$sb.Append(('line {0:d6}: {1}{2}' -f $line, ($ws -join ' '), $eol))
        $line++
    }
    return $sb.ToString()
}
$zh = -join ([char]0x4E2D, [char]0x6587, [char]0x6A94, [char]0x540D)   # four CJK characters
$zhText = -join ([char]0x7E41, [char]0x9AD4, [char]0x4E2D, [char]0x6587, [char]0x6E2C, [char]0x8A66)

Write-Bytes (Join-Path $Corpus 'a.txt')        $Utf8.GetBytes((New-Text 20000 "`n"))
Write-Bytes (Join-Path $Corpus 'b-crlf.txt')   $Utf8.GetBytes((1..200 | ForEach-Object { "$zhText $_`r`n" }) -join '')
Write-Bytes (Join-Path $Corpus 'text512k.txt') $Utf8.GetBytes((New-Text 524288 "`n"))
Write-Bytes (Join-Path $Corpus 'sub\c.txt')    $Utf8.GetBytes("nested file`n")
Write-Bytes (Join-Path $Corpus 'empty.txt')    ([byte[]]@())
Write-Bytes (Join-Path $Corpus 'zeros.bin')    (New-Object byte[] 1048576)
$rand = New-Object byte[] 16384; $rng.NextBytes($rand)
Write-Bytes (Join-Path $Corpus 'random.bin')   $rand
# >100 characters: forces the tar writer past the ustar name field (GNU
# longname or pax), the layer most likely to disagree between tar dialects.
$longName = 'long-' + ('x' * 110) + '.txt'
Write-Bytes (Join-Path $Corpus $longName)      $Utf8.GetBytes("long name`n")
Write-Bytes (Join-Path $Corpus "$zh.txt")      $Utf8.GetBytes("$zhText`n")

$corpusFiles = Get-ChildItem -LiteralPath $Corpus -Recurse -File | Sort-Object FullName
$sums = foreach ($f in $corpusFiles) {
    $rel = $f.FullName.Substring($Corpus.Length + 1) -replace '\\', '/'
    '{0}  {1}' -f (Sha $f.FullName), $rel
}
# sha256sum -c format, LF, so the Linux side verifies extractions directly.
Write-Bytes (Join-Path $Corpus 'SHA256SUMS') $Utf8.GetBytes((($sums -join "`n") + "`n"))

# ---------------------------------------------------------------------------
# Archives. Each entry: output name, 7z arguments after "a", input spec.
# Inputs are given relative to the corpus directory so archive paths are
# rooted there.
# ---------------------------------------------------------------------------
$single = 'text512k.txt'
$jobs = New-Object System.Collections.Generic.List[object]
# ($input would be PowerShell's automatic pipeline variable; keep clear of it.)
function Add-Job($group, $name, [string[]]$switches, $inputSpec) {
    $jobs.Add([pscustomobject]@{ Group = $group; Name = $name; Switches = $switches; Input = $inputSpec })
}

# Single-file codecs. One variant each: -mmt=1 and -mmt=4 were tried when this
# generator was written (2026-11-04) and produced byte-identical files for all
# five codecs - the standalone handlers ignore the thread switch. Which wire
# format each one gets is fixed by the handler instead: .zst/.br/.lz4 are
# plain frames, .lz5/.liz are always the skippable-frame container. The
# manifest's first 16 bytes make that visible per file.
foreach ($c in @(@('zstd', 'zst'), @('brotli', 'br'), @('lz4', 'lz4'), @('lz5', 'lz5'), @('lizard', 'liz'),
                 @('xz', 'xz'), @('gzip', 'gz'), @('bzip2', 'bz2'))) {
    $fmt, $ext = $c
    Add-Job 'single' "single/$single.$ext" @("-t$fmt") $single
}

# One-step chained tar archives of the whole corpus.
foreach ($ext in 'tar.zst', 'tar.br', 'tar.lz4', 'tar.lz5', 'tar.liz', 'tar.gz', 'tar.xz', 'tar.bz2') {
    Add-Job 'chain' "chain/corpus.$ext" @("-t$ext") '*'
}

# .7z with each added method, lzma2 as the baseline, and two -mmt=4 variants.
# The variants came out byte-identical to the defaults (the .7z coders ignore
# the switch for this input); they are kept because REPORT.md cites them.
foreach ($m in 'zstd', 'brotli', 'lz4', 'lz5', 'lizard', 'flzma2', 'lzma2') {
    Add-Job '7z' "7z/corpus-$m.7z" @('-t7z', "-m0=$m") '*'
}
Add-Job '7z' '7z/corpus-zstd-mt4.7z'   @('-t7z', '-m0=zstd',   '-mmt=4') '*'
Add-Job '7z' '7z/corpus-brotli-mt4.7z' @('-t7z', '-m0=brotli', '-mmt=4') '*'

# Record which binary made the fixtures, not just which source it was built
# from: the manifest is the Linux side's only evidence of provenance.
$commit = (& git -C $RepoRoot rev-parse --short HEAD 2>$null)
if (& git -C $RepoRoot status --porcelain --untracked-files=no 2>$null) { $commit += ' (dirty)' }
$exeSha = Sha $SevenZip
$dllSha = Sha (Join-Path $BinDir '7z.dll')

$rows = New-Object System.Collections.Generic.List[string]
Push-Location $Corpus
try {
    foreach ($j in $jobs) {
        $out = Join-Path $WinDir ($j.Name -replace '/', '\')
        $dir = Split-Path $out -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
        $szArgs = @('a') + $j.Switches + @('-y', $out, $j.Input)
        $r = Sz $szArgs
        if ($r.Code -ne 0 -or -not (Test-Path $out)) {
            throw ("7z failed for {0} (exit {1}):`n{2}" -f $j.Name, $r.Code, $r.Out)
        }
        $cmd = '7z a ' + (($j.Switches + @('-y', '<out>', $j.Input)) -join ' ')
        $rows.Add(('| `{0}` | {1} | `{2}` | `{3}` | `{4}` |' -f $j.Name, (Get-Item -LiteralPath $out).Length, (Head16 $out), (Sha $out), $cmd))
        Write-Host ('  {0,-40} {1,9} bytes  {2}' -f $j.Name, (Get-Item -LiteralPath $out).Length, (Head16 $out).Substring(0, 11))
    }
} finally { Pop-Location }

# ---------------------------------------------------------------------------
# Manifest
# ---------------------------------------------------------------------------
$corpusRows = foreach ($f in $corpusFiles) {
    $rel = $f.FullName.Substring($Corpus.Length + 1) -replace '\\', '/'
    '| `{0}` | {1} | `{2}` |' -f $rel, $f.Length, (Sha $f.FullName)
}
$manifest = @"
# Interop fixtures - Windows side

Generated by ``build\New-InteropVectors.ps1`` on $(Get-Date -Format 'yyyy-MM-dd') from commit ``$commit``
with ``$banner`` ($Platform; 7z.exe sha256 ``$exeSha``, 7z.dll sha256 ``$dllSha``).

All archives were produced by this tree's ``7z.exe`` with the working directory set to
``corpus/``, so member paths are relative to it. ``<out>`` stands for the output path.
Every file under ``corpus/``, ``windows/`` and ``linux/`` is stored with ``-text`` (no
line-ending translation), so the sha256 values below hold on every platform.

## Reading the first 16 bytes

| Bytes | Meaning |
|---|---|
| ``28 B5 2F FD`` | zstd frame (RFC 8878) |
| ``04 22 4D 18`` | LZ4 frame |
| ``50 2A 4D 18`` | skippable frame: mcmilk's multi-threaded container (zstdmt wire format), not a plain stream |
| ``FD 37 7A 58 5A 00`` | xz |
| ``1F 8B`` | gzip |
| ``42 5A 68`` | bzip2 |
| ``37 7A BC AF 27 1C`` | 7z |
| other | brotli has no signature; LZ5 and Lizard frames carry their own magic (``05 22 4D 18`` / ``06 22 4D 18``) |

Observed when generating: ``-mmt=1`` and ``-mmt=4`` give byte-identical output to the default
for every standalone codec, so only one file per codec is kept. The standalone ``.lz5`` and
``.liz`` handlers always write the skippable-frame container; ``.zst``, ``.br`` and ``.lz4``
always write a plain frame. Expect Linux tools to read the plain frames and to reject the
containers; whichever way it goes, record it.

## corpus/

Check extractions with ``sha256sum -c corpus/SHA256SUMS`` (same hashes as below).

| File | Bytes | SHA-256 |
|---|---|---|
$($corpusRows -join "`n")

## windows/

| File | Bytes | First 16 bytes | SHA-256 | Command |
|---|---|---|---|---|
$($rows -join "`n")
"@
Write-Bytes (Join-Path $OutDir 'MANIFEST.md') $Utf8.GetBytes(($manifest -replace "`r`n", "`n"))

Write-Host ("`n{0} corpus files, {1} archives, manifest at {2}" -f $corpusFiles.Count, $jobs.Count, (Join-Path $OutDir 'MANIFEST.md'))

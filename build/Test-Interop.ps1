<#
.SYNOPSIS
    Read the Linux-produced interop vectors back with this tree's 7z.exe.

.DESCRIPTION
    The reverse half of test\interop: test\interop\linux\MANIFEST.md lists
    archives written by Linux tools (GNU tar, bsdtar, zstd, brotli, lz4), each
    with the sha256 of the payload it must decode to. This script runs
    7z l / 7z t / 7z x on every one of them and compares what came out:

      * tar/corpus.* and brotli/corpus.gnutar.tar.br  - the whole corpus;
        every extracted file is checked against corpus\SHA256SUMS
      * tar/sparse.*                                    - one 4 MiB sparse file
      * everything else                                 - one payload file whose
        sha256 the manifest's notes column states

    Verdicts:
      PASS             decoded, every byte matched
      REJECTED-CLEAN   a vector 7-ZSTar is expected to refuse (LZ4 legacy
                       frames) was refused with a documented 7z exit code and
                       an ordinary error line ("Cannot open the file as [lz4]
                       archive"), no "Unspecified error", no crash
      REJECTED-UNCLEAN same, but the refusal was a crash or an Unspecified error
      UNEXPECTED-OK    an expected-to-refuse vector decoded correctly after all
      UPSTREAM-LIMIT   pax-format GNU sparse 1.0 entries came out compacted
                       under GNUSparseFile.<n>/; upstream 7-Zip 26.05 does the
                       same (checked 2026-11-04), so it is recorded, not failed
      FAIL             anything else

    brotli large-window (WBITS 30) streams were first expected to be refused;
    the 2026-11-04 run showed 7-ZSTar decodes them, so they are now required
    to decode and a refusal would be a regression (FAIL).

    Exit code 0 when nothing FAILed and no rejection was unclean; 1 otherwise.

.PARAMETER Platform
    Build output to use (x64 by default).

.PARAMETER BinDir
    Directory holding 7z.exe. Defaults to the Console build output; 7z.dll is
    borrowed from the Format7zF bundle the same way Test-Smoke.ps1 does.

.PARAMETER InteropDir
    The test\interop directory. Defaults to <repo>\test\interop.
#>
#Requires -Version 7.2
[CmdletBinding()]
param(
    [ValidateSet('x64', 'x86', 'arm64')]
    [string]$Platform = 'x64',
    [string]$BinDir,
    [string]$InteropDir,

    # Use binaries that carry no source stamp (an unpacked release, say) or
    # whose stamp no longer matches the source. Off by default; the skip is
    # logged to build\logs\freshness-skips.log. See build\SourceStamp.ps1.
    [switch]$SkipFreshnessCheck
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'SourceStamp.ps1')
# .NET IO resolves relative paths against the process directory, cmdlets
# against PowerShell's location; absolute paths keep the two in agreement.
function Resolve-Full($p) { $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($p) }

# 7z.dll is borrowed from the build tree only for the default BinDir; a
# caller who points at a specific directory (an unpacked release, say) gets
# exactly what is there, untouched.
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
# The interop matrix proves nothing about this tree unless the binaries it
# runs come from it: hold the console exe, and the build-tree dll it borrowed,
# to the source stamp.
$freshTargets = @($SevenZip)
if (-not $PSBoundParameters.ContainsKey('BinDir') -and (Test-Path $dllSrc)) { $freshTargets += $dllSrc }
else { $freshTargets += (Join-Path $BinDir '7z.dll') }   # no build-tree dll to hold: hold the one in use
Assert-ArtifactFresh -Path $freshTargets -Skip:$SkipFreshnessCheck -Caller 'Test-Interop.ps1'
$banner = (& $SevenZip 2>&1 | Select-Object -First 3 | Where-Object { $_ -match '7-ZSTar' } | Select-Object -First 1)
if (-not $banner) { throw "$SevenZip did not identify itself as 7-ZSTar (or failed to run)" }

$InteropDir = $(if ($InteropDir) { Resolve-Full $InteropDir } else { Join-Path $RepoRoot 'test\interop' })
$LinuxDir = Join-Path $InteropDir 'linux'
$Manifest = Join-Path $LinuxDir 'MANIFEST.md'
if (-not (Test-Path $Manifest)) { throw "Linux manifest not found: $Manifest" }
$sumsFile = Join-Path $InteropDir 'corpus\SHA256SUMS'
if (-not (Test-Path $sumsFile)) { throw "corpus checksums not found: $sumsFile" }

function Sha($path) { (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() }
# Same trick as Test-Smoke.ps1: switches go through an array so PowerShell's
# parser cannot mangle them.
function Sz {
    param([string[]]$SzArgs)
    $out = & $SevenZip @SzArgs 2>&1
    return @{ Out = ($out -join "`n"); Code = $LASTEXITCODE }
}
function FirstError($text) {
    $lines = @($text -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match 'ERROR|Error|error') {
            # 7z prints "ERROR: <path>" and puts the reason on the next line.
            if ($lines[$i] -match '^ERROR: ' -and $i + 1 -lt $lines.Count) { return $lines[$i] + ' - ' + $lines[$i + 1] }
            return $lines[$i]
        }
    }
    if ($lines.Count) { return $lines[-1] }
    return ''
}

# Expected corpus hashes (sha256sum -c format, LF). The Linux tars were made
# with "tar -cf <out> -- *" inside corpus/, so SHA256SUMS itself is a member
# too; expect it alongside the nine files it lists.
$corpusSums = @{}
foreach ($l in [System.IO.File]::ReadAllLines($sumsFile)) {
    if ($l -match '^([0-9a-f]{64})\s+(.+)$') { $corpusSums[$Matches[2]] = $Matches[1] }
}
$corpusSums['SHA256SUMS'] = Sha $sumsFile
# The sparse vectors carry a 4 MiB file that is not in the repo; its sha256
# comes from the manifest notes like any other payload, only the size is
# stated here.
$sparseLen = 4194304

# ---------------------------------------------------------------------------
# Parse the manifest tables. Columns: file | bytes | first16 | sha256 | cwd |
# generate | verify | result | notes. Pipes inside commands are escaped as \|.
# A row that does not fit is an error, not a skip: the set of files parsed
# must be exactly the set linux/SHA256SUMS lists, so a format change cannot
# silently drop vectors from the run.
# ---------------------------------------------------------------------------
$tick = [char]96
$shaInNotes = [regex]('sha256 ' + $tick + '([0-9a-f]{64})' + $tick)
$vectors = foreach ($line in (Get-Content -LiteralPath $Manifest -Encoding utf8)) {
    if ($line -notmatch ('^\| ' + $tick)) { continue }
    $cols = ($line -split '(?<!\\) \| ') | ForEach-Object { $_.Trim(' ', '|').Trim($tick) }
    if ($cols.Count -lt 9) { throw "manifest row has $($cols.Count) columns, expected 9: $line" }
    if ($cols[3] -notmatch '^[0-9a-f]{64}$') { throw "manifest row has no sha256 in column 4: $line" }
    $m = $shaInNotes.Match($cols[-1])
    [pscustomobject]@{
        Name       = $cols[0]
        Sha        = $cols[3]
        PayloadSha = $(if ($m.Success) { $m.Groups[1].Value } else { $null })
    }
}
$listed = @{}
foreach ($l in [System.IO.File]::ReadAllLines((Join-Path $LinuxDir 'SHA256SUMS'))) {
    if ($l -match '^[0-9a-f]{64}\s+(.+)$') { $listed[$Matches[1]] = $true }
}
$parsedNames = @($vectors | ForEach-Object { $_.Name })
$onlyInSums = @($listed.Keys | Where-Object { $_ -notin $parsedNames })
$onlyInManifest = @($parsedNames | Where-Object { -not $listed.ContainsKey($_) })
if ($vectors.Count -eq 0 -or $onlyInSums.Count -or $onlyInManifest.Count) {
    throw ("manifest and linux/SHA256SUMS disagree - only in SHA256SUMS: [{0}]; only in MANIFEST: [{1}]" -f ($onlyInSums -join ', '), ($onlyInManifest -join ', '))
}

# Vectors 7-ZSTar is expected to refuse (see the verdict list above).
$expectReject = @('lz4-legacy')

Write-Host "7-ZSTar interop read-back  ($Platform)  $($vectors.Count) Linux vectors"
Write-Host "  binary: $SevenZip"
Write-Host "  banner: $banner"
Write-Host ""

$rows = New-Object System.Collections.Generic.List[object]
$Work = Join-Path $env:TEMP ("7zstar-interop-" + [System.IO.Path]::GetRandomFileName())
try {
New-Item -ItemType Directory -Force $Work | Out-Null
foreach ($v in $vectors) {
    $path = Join-Path $LinuxDir ($v.Name -replace '/', '\')
    $verdict = ''; $detail = ''
    $lCode = $tCode = $xCode = $null

    if (-not (Test-Path -LiteralPath $path)) {
        $verdict = 'FAIL'; $detail = 'file missing'
    } elseif ((Sha $path) -ne $v.Sha) {
        $verdict = 'FAIL'; $detail = 'vector sha256 differs from manifest (transport/checkout damage)'
    } else {
        $outDir = Join-Path $Work ([System.IO.Path]::GetRandomFileName())
        New-Item -ItemType Directory -Force $outDir | Out-Null
        $l = Sz @('l', $path);                    $lCode = $l.Code
        $t = Sz @('t', $path);                    $tCode = $t.Code
        $x = Sz @('x', $path, "-o$outDir", '-y'); $xCode = $x.Code

        # One-step chains should land the members directly; if only a .tar
        # came out, unpack it too and say so.
        $twoStep = $false; $innerFail = ''
        $produced = @(Get-ChildItem -LiteralPath $outDir -Recurse -File)
        if ($xCode -eq 0 -and $produced.Count -eq 1 -and $produced[0].Extension -eq '.tar') {
            $inner = Join-Path $outDir 'inner'
            New-Item -ItemType Directory -Force $inner | Out-Null
            $x2 = Sz @('x', $produced[0].FullName, "-o$inner", '-y')
            if ($x2.Code -eq 0) { $twoStep = $true; $outDir = $inner; $produced = @(Get-ChildItem -LiteralPath $outDir -Recurse -File) }
            else { $innerFail = "inner .tar failed (exit $($x2.Code)): " + (FirstError $x2.Out) }
        }

        $wantReject = ($expectReject | Where-Object { $v.Name -like "*$_*" }).Count -gt 0
        if ($xCode -ne 0 -or $tCode -ne 0 -or $lCode -ne 0) {
            $allOut = $l.Out + "`n" + $t.Out + "`n" + $x.Out
            $err = FirstError $allOut
            # 7z's documented exit codes are 1, 2, 7, 8 and 255; anything else
            # (a negative NTSTATUS, say) is a crash, not a rejection, however
            # quiet the output was.
            $codes = @($lCode, $tCode, $xCode)
            $unclean = ($allOut -match 'Unspecified|exception|Access violation') -or
                       (@($codes | Where-Object { $_ -ne 0 -and $_ -notin 1, 2, 7, 8, 255 }).Count -gt 0)
            if ($wantReject) {
                $verdict = $(if ($unclean) { 'REJECTED-UNCLEAN' } else { 'REJECTED-CLEAN' })
            } else {
                $verdict = 'FAIL'
            }
            $detail = $err
        } else {
            # Compare what came out.
            $bad = @()
            if ($innerFail) { $bad += $innerFail }
            if ($v.Name -like 'tar/sparse.*') {
                $f = $produced | Where-Object { $_.Name -eq 'sparse.bin' } | Select-Object -First 1
                if (-not $v.PayloadSha) { $bad += 'manifest gives no sha256 for sparse.bin' }
                elseif (-not $f) { $bad += 'missing sparse.bin' }
                elseif ($f.Length -ne $sparseLen) { $bad += "sparse.bin is $($f.Length) bytes, want $sparseLen" }
                elseif ((Sha $f.FullName) -ne $v.PayloadSha) { $bad += 'sparse.bin sha256 mismatch' }
            } elseif ($v.Name -like 'tar/corpus.*' -or $v.Name -like '*/corpus.*.tar.*') {
                foreach ($rel in $corpusSums.Keys) {
                    $f = Join-Path $outDir ($rel -replace '/', '\')
                    if (-not (Test-Path -LiteralPath $f)) { $bad += "missing $rel"; continue }
                    if ((Sha $f) -ne $corpusSums[$rel]) { $bad += "sha256 mismatch $rel" }
                }
                $extra = $produced.Count - $corpusSums.Count
                if ($extra -gt 0) { $bad += "$extra unexpected extra file(s)" }
            } else {
                if (-not $v.PayloadSha) { $bad += 'manifest gives no payload sha256' }
                elseif ($produced.Count -ne 1) { $bad += "expected 1 output file, got $($produced.Count)" }
                elseif ((Sha $produced[0].FullName) -ne $v.PayloadSha) { $bad += 'payload sha256 mismatch' }
            }
            # pax-format GNU sparse 1.0 entries (bsdtar's default, GNU tar
            # --format=pax --sparse) come out as GNUSparseFile.<n>/<name>
            # holding the compacted data instead of the expanded file.
            # Official 7-Zip 26.05 does exactly the same on the inner .tar
            # (checked 2026-11-04), so this is an upstream limitation, not a
            # regression; report it as such rather than as a failure.
            # Only the complaints those members account for are excused; any
            # other member going wrong in the same archive is still a FAIL.
            $paxSparse = @($produced | Where-Object { $_.FullName.Substring($outDir.Length + 1) -like 'GNUSparseFile.*' })
            $sparseNames = @($paxSparse | ForEach-Object { $_.Name })
            $residual = @($bad | Where-Object {
                $b = $_
                $explained = $false
                foreach ($n in $sparseNames) {
                    if ($b -eq "missing $n" -or $b -like "$n is * bytes, want *" -or $b -eq "$n sha256 mismatch") { $explained = $true }
                }
                if ($b -match '^(\d+) unexpected extra file\(s\)$' -and [int]$Matches[1] -le $sparseNames.Count) { $explained = $true }
                -not $explained
            })
            if ($bad.Count -gt 0 -and $paxSparse.Count -gt 0 -and $residual.Count -eq 0) {
                $verdict = 'UPSTREAM-LIMIT'
                $detail = 'pax GNU.sparse 1.0 entry left compacted as ' + (($paxSparse | ForEach-Object { $_.FullName.Substring($outDir.Length + 1) }) -join ', ') + ' (official 7-Zip 26.05 behaves the same)'
            }
            elseif ($bad.Count -gt 0) { $verdict = 'FAIL'; $detail = ($bad -join '; ') }
            elseif ($wantReject)  { $verdict = 'UNEXPECTED-OK'; $detail = 'decoded correctly although a rejection was expected' }
            else                  { $verdict = 'PASS'; $detail = $(if ($twoStep) { 'two-step (.tar came out first)' } else { '' }) }
        }
    }
    $rows.Add([pscustomobject]@{ Vector = $v.Name; L = $lCode; T = $tCode; X = $xCode; Verdict = $verdict; Detail = $detail })
    Write-Host ('  {0,-16} {1,-50} l={2} t={3} x={4}  {5}' -f $verdict, $v.Name, $lCode, $tCode, $xCode, $detail)
}
} finally {
    # Whatever threw above, do not leave the extraction scratch space behind.
    Remove-Item $Work -Recurse -Force -ErrorAction SilentlyContinue
}

$counts = $rows | Group-Object Verdict | ForEach-Object { '{0} {1}' -f $_.Count, $_.Name }
Write-Host ""
Write-Host ("summary: " + ($counts -join ', '))
$failed = @($rows | Where-Object { $_.Verdict -in 'FAIL', 'REJECTED-UNCLEAN' }).Count
if ($failed -gt 0) { Write-Host "$failed vector(s) failed"; exit 1 }
Write-Host "all Linux vectors read back as expected"
exit 0

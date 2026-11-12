# 7-ZSTar functional smoke tests.
#
#   pwsh build\Test-Smoke.ps1                 # test the x64 build output
#   pwsh build\Test-Smoke.ps1 -Platform x86
#   pwsh build\Test-Smoke.ps1 -BinDir <dir> -SkipFreshnessCheck   # an unpacked release (it has no stamp)
#
# Exits non-zero if any check fails, so CI can gate on it.
#
# Two habits baked in deliberately, both learned the hard way:
#   * Every 7z invocation uses an explicit path. A bare "7z" on this machine
#     resolves to an unrelated archiver via a Store app-execution alias, and
#     the whole suite then silently tests the wrong binary.
#   * The banner is asserted before anything else, for the same reason.

[CmdletBinding()]
param(
    [ValidateSet('x64', 'x86', 'arm64')]
    [string]$Platform = 'x64',

    # Directory holding 7z.exe + 7z.dll. Defaults to the Console build output.
    [string]$BinDir,

    # Test binaries that carry no source stamp (an unpacked release, say) or
    # whose stamp no longer matches the source. Off by default: a green run
    # on stale binaries says nothing about the code in this tree. The skip is
    # logged to build\logs\freshness-skips.log.
    [switch]$SkipFreshnessCheck
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'SourceStamp.ps1')

if (-not $BinDir) { $BinDir = Join-Path $RepoRoot "CPP\7zip\UI\Console\$Platform" }
$SevenZip = Join-Path $BinDir '7z.exe'
if (-not (Test-Path $SevenZip)) { throw "7z.exe not found: $SevenZip" }

# Everything below is only worth its green if the binaries come from the source
# as it is now. Check every build-tree binary this run touches: the console
# 7z.exe (unless -BinDir points elsewhere - then that directory is held to the
# same rule), the 7z.dll it borrows, and the GUI the string checks read.
$freshTargets = @($SevenZip)
$freshDll = Join-Path $RepoRoot "CPP\7zip\Bundles\Format7zF\$Platform\7z.dll"
$freshFm = Join-Path $RepoRoot "CPP\7zip\UI\FileManager\$Platform\7zFM.exe"
if (Test-Path $freshDll) {
    $freshTargets += $freshDll
} elseif (-not $PSBoundParameters.ContainsKey('BinDir')) {
    # A 7z.dll left in the Console directory by an earlier run is a copy of
    # some older Format7zF build; the Console stamp lists it but did not make it.
    throw "Format7zF output missing: $freshDll. Build it first (build\Build.ps1); a 7z.dll left in $BinDir by an earlier run is not evidence."
} elseif (Test-Path (Join-Path $BinDir '7z.dll')) {
    $freshTargets += (Join-Path $BinDir '7z.dll')   # an explicit -BinDir brings its own
}
if (Test-Path (Join-Path $BinDir '7zFM.exe')) { $freshTargets += (Join-Path $BinDir '7zFM.exe') }
elseif (Test-Path $freshFm) { $freshTargets += $freshFm }
Assert-ArtifactFresh -Path $freshTargets -Skip:$SkipFreshnessCheck -Caller 'Test-Smoke.ps1'

# 7z.exe loads 7z.dll from its own directory; the Console build output does not
# contain one, so borrow the Format7zF bundle's when testing a build tree.
#
# Copied unconditionally, every run. Copying only when absent would leave a
# stale 7z.dll behind after Format7zF is rebuilt, and the suite would then pass
# against the previous build - the exact "you tested a different binary than
# you think" failure the banner check below exists to catch.
$dll = Join-Path $BinDir '7z.dll'
$dllSrc = Join-Path $RepoRoot "CPP\7zip\Bundles\Format7zF\$Platform\7z.dll"
if (Test-Path $dllSrc) {
    Copy-Item $dllSrc $dll -Force
} elseif (-not (Test-Path $dll)) {
    throw "7z.dll not found next to 7z.exe nor at $dllSrc"
}

$Work = Join-Path $env:TEMP ("7zstar-smoke-" + [System.IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Force $Work | Out-Null

$script:Pass = 0
$script:Fail = 0

function Check($name, [scriptblock]$test) {
    try {
        $r = & $test
        if ($r -is [string] -and $r) { throw $r }
        Write-Host ("  PASS  {0}" -f $name)
        $script:Pass++
    } catch {
        Write-Host ("  FAIL  {0}`n          {1}" -f $name, $_.Exception.Message)
        $script:Fail++
    }
}

# Invoke 7z with the format switch built as a variable. Passing a literal
# "-ttar.br" through PowerShell's argument parser mangles it into a file named
# ".br"; going through a variable keeps it intact.
function Sz {
    param([string[]]$SzArgs)
    $out = & $SevenZip @SzArgs 2>&1
    return @{ Out = ($out -join "`n"); Code = $LASTEXITCODE }
}

function Sha($path) { (Get-FileHash $path -Algorithm SHA256).Hash }

Write-Host "7-ZSTar smoke tests  ($Platform)"
Write-Host "  binary: $SevenZip"
Write-Host ""

# --- identity --------------------------------------------------------------

Check "banner identifies 7-ZSTar (not another archiver via PATH alias)" {
    $r = Sz @('i')
    if ($r.Out -notmatch '7-ZSTar') { return "banner was: " + ($r.Out -split "`n")[0] }
}

# The date is stamped at build time. nmake tracks no header dependencies, so a
# stale object would keep yesterday's date with every other check green. Only
# binaries built from this tree can be held to this tree's header. All platforms
# share that header: after building one on a new day, the others fail this
# check until they are rebuilt too.
$buildDate = $null
$dateHeader = Join-Path $RepoRoot 'C\7zBuildDate.h'
if (-not $PSBoundParameters.ContainsKey('BinDir') -and (Test-Path $dateHeader)) {
    $buildDate = [regex]::Match((Get-Content $dateHeader -Raw), '\d{4}-\d{2}-\d{2}').Value
    Check "banner shows the build date" {
        # An empty date would make Contains(": ") true on any banner.
        if (-not $buildDate) { return "no yyyy-mm-dd date in $dateHeader" }
        $r = Sz @('i')
        if (-not $r.Out.Contains(": $buildDate")) { return "expected $buildDate in: " + ($r.Out -split "`n")[1] }
    }
} else {
    Write-Host "  SKIP  build date checks (binaries not built from this tree, or no C\7zBuildDate.h)"
}

# The banner above only covers the console build. The GUI carries its own
# strings in its resources, and the rebrand really did leave "About 7-Zip" and
# an upstream link label sitting in the About dialog long after every other
# surface said 7-ZSTar - with a green build and a green test suite. Dialog
# strings live in the PE as UTF-16LE, so probe the bytes at both alignments.
$fmExe = Join-Path $BinDir '7zFM.exe'
if (-not (Test-Path $fmExe)) {
    $fmExe = Join-Path $RepoRoot "CPP\7zip\UI\FileManager\$Platform\7zFM.exe"
}
if (Test-Path $fmExe) {
    $fmBytes = [System.IO.File]::ReadAllBytes($fmExe)
    $fmText = @(
        [System.Text.Encoding]::Unicode.GetString($fmBytes),
        [System.Text.Encoding]::Unicode.GetString($fmBytes, 1, $fmBytes.Length - 1)
    )
    function InFm([string]$needle) {
        foreach ($t in $fmText) { if ($t.Contains($needle)) { return $true } }
        return $false
    }

    Check "file manager resources name 7-ZSTar, not 7-Zip" {
        if (-not (InFm 'About 7-ZSTar')) { return "'About 7-ZSTar' missing from $fmExe" }
        if (InFm 'About 7-Zip') { return "upstream caption 'About 7-Zip' is still in the binary" }
        if (InFm 'www.7-zip.org') { return "upstream home-page label is still in the binary" }
    }

    Check "About dialog states the fork relationship and licence" {
        if (-not (InFm 'independent fork of 7-Zip')) { return "fork disclaimer missing" }
        if (-not (InFm 'LICENSE-EXCEPTIONS.md')) { return "licence-exceptions pointer missing" }
    }

    # LegalCopyright in the version resource holds both names on one line, so
    # only these exact forms prove the dialog itself still shows them: the
    # fork's own year, and upstream's line ending where the string ends. Taking
    # upstream's line from the banner also catches the literals drifting apart.
    Check "About dialog names both copyright holders" {
        $upstream = [regex]::Match((Sz @('i')).Out, 'Copyright \(c\) \d{4}-\d{4} Igor Pavlov').Value
        if (-not $upstream) { return "upstream copyright missing from the banner" }
        if (-not (InFm "$upstream`0")) { return "dialog does not show the banner's line: $upstream" }
        if (-not ($fmText -match 'Copyright \(c\) \d{4}(-\d{4})? 7-ZSTar contributors')) { return "fork copyright line missing from $fmExe" }
    }

    Check "About dialog links to the website" {
        if (-not (InFm 'https://www.7zstar.com')) { return "website URL missing from $fmExe" }
        if (InFm 'Project Page') { return "old button label is still in the binary" }
    }

    # 7-ZSTar: the third button. The label must say Donate (Support reads as
    # technical support), and it opens the root page's #donate section.
    Check "About dialog has the Donate button and its link" {
        if (-not (InFm 'Donate')) { return "'Donate' missing from $fmExe" }
        if (-not (InFm 'https://www.7zstar.com/#donate')) { return "donate URL missing from $fmExe" }
        # Deliberately blunt and therefore brittle: this is a substring search of
        # the whole PE (both alignments), so any other resource or import that
        # ever contains the word "Support" fails it. If that happens, narrow the
        # probe to the dialog's own button text rather than deleting it - the
        # point is that the button must not be labelled "Support".
        if (InFm 'Support') { return "'Support' is in the binary - the button must say Donate" }
    }

    if ($buildDate) {
        Check "About dialog shows the build date" {
            if (-not (InFm $buildDate)) { return "build date $buildDate missing from $fmExe" }
        }
    }

    # The "Integrate 7-ZSTar to shell context menu" option writes these keys.
    # Upstream's "\7-Zip" made it overwrite official 7-Zip's handler keys. They
    # are narrow (char) literals, so they sit in the PE as single bytes.
    $fmNarrow = [System.Text.Encoding]::GetEncoding(28591).GetString($fmBytes)
    Check "file manager uses 7-ZSTar's handler key names, not 7-Zip's" {
        if (-not $fmNarrow.Contains('\shellex\ContextMenuHandlers\7-ZSTar')) { return "7-ZSTar handler key name missing from $fmExe" }
        # Registry key names are case-insensitive, so any spelling of upstream's would clash.
        if ($fmNarrow.IndexOf('Handlers\7-Zip', [StringComparison]::OrdinalIgnoreCase) -ge 0) { return "official 7-Zip's handler key name is still in the binary" }
    }

    # resource.rc keeps upstream's bitmap lines behind an #if 0, so a merge that
    # loses the fence brings upstream's art back with a green build. RC stores a
    # BMP without its 14-byte file header, so each one can be searched for as is.
    $artDir = Join-Path $RepoRoot 'CPP\7zip\UI\FileManager\7zstar'
    if (Test-Path $artDir) {
        function InFmDib([string]$bmp) {
            $b = [System.IO.File]::ReadAllBytes($bmp)
            $dib = [System.Text.Encoding]::GetEncoding(28591).GetString($b, 14, $b.Length - 14)
            return $fmNarrow.IndexOf($dib, [StringComparison]::Ordinal) -ge 0
        }
        $artCount = 7 * 5   # buttons x sizes
        Check "file manager embeds 7-ZSTar's toolbar art, not upstream's" {
            $own = @(Get-ChildItem $artDir -Filter *.bmp)
            if ($own.Count -ne $artCount) { return "expected $artCount bitmaps in $artDir, found $($own.Count)" }
            $missing = @($own | Where-Object { -not (InFmDib $_.FullName) })
            if ($missing) { return "not in the binary: $($missing.Name -join ', ')" }
            $upstream = @(Get-ChildItem (Split-Path $artDir) -Filter *.bmp | Where-Object { InFmDib $_.FullName })
            if ($upstream) { return "upstream art is in the binary: $($upstream.Name -join ', ')" }
        }

        # Art is indexed from IDB_ADD, so a new upstream button would load past the
        # last bitmap and show the next button's picture, or nothing.
        # Toolbar7zstar.h can only guard the IDs it names; this catches a new one.
        Check "resource.h has no toolbar bitmap ID without art" {
            $known = 'ADD', 'EXTRACT', 'TEST', 'COPY', 'MOVE', 'DELETE', 'INFO' | ForEach-Object { "IDB_$_", "IDB_${_}2" }
            $header = Join-Path $RepoRoot 'CPP\7zip\UI\FileManager\resource.h'
            $ids = @(Select-String -LiteralPath $header -Pattern '^#define\s+(IDB_\w+)' | ForEach-Object { $_.Matches[0].Groups[1].Value })
            $unknown = @($ids | Where-Object { $_ -notin $known })
            if ($unknown) { return "no toolbar art for: $($unknown -join ', ')" }
            if ($ids.Count -ne $known.Count) { return "expected $($known.Count) IDB_ defines in resource.h, found $($ids.Count)" }
        }

        # Toolbar7zstar.h computes 1000 + button * 5 + size index; toolbar.rc is
        # written by hand, and two swapped IDs would put one button's picture on
        # another with every other check green.
        Check "toolbar.rc gives each bitmap the ID Toolbar7zstar.h computes" {
            $buttons = 'Add', 'Extract', 'Test', 'Copy', 'Move', 'Delete', 'Info'
            $sizes = 24, 36, 48, 72, 96
            $rc = Join-Path $artDir 'toolbar.rc'
            $bad = New-Object System.Collections.Generic.List[string]
            $seen = 0
            foreach ($m in [regex]::Matches((Get-Content -LiteralPath $rc -Raw), '(?m)^(\d+)\s+BITMAP\s+"[^"]*/(\w+)-(\d+)\.bmp"')) {
                $seen++
                $b = [array]::IndexOf($buttons, $m.Groups[2].Value)
                $s = [array]::IndexOf($sizes, [int]$m.Groups[3].Value)
                $want = if ($b -lt 0 -or $s -lt 0) { -1 } else { 1000 + $b * $sizes.Count + $s }
                if ([int]$m.Groups[1].Value -ne $want) { $bad.Add("$($m.Groups[2].Value)-$($m.Groups[3].Value) has ID $($m.Groups[1].Value), expected $want") }
            }
            if ($seen -ne $artCount) { return "expected $artCount BITMAP lines in toolbar.rc, found $seen" }
            if ($bad.Count) { return ($bad -join '; ') }
        }
    } else {
        Write-Host "  SKIP  toolbar art check (vendored sources not in $RepoRoot)"
    }
} else {
    Write-Host "  SKIP  file manager checks (7zFM.exe not in $BinDir nor in the build tree)"
}

# --- About-dialog button strings (Lang\donate.json -> strings 962/963) ------
#
# A control id is its language id, so the buttons only translate if every file
# carries "962 / word / 963 / word" and the explicit 1003 line below it did not
# move. Lang\ is re-vendored wholesale from an upstream MSI; if rebrand.py is
# skipped (files copied over by hand) they come back without them and nothing
# else fails - the buttons just quietly show English everywhere. (rebrand.py
# itself refuses to run without a readable donate.json, and the check below
# fails when the file is missing.)
$langDir = Join-Path $RepoRoot 'Lang'
$donateJson = Join-Path $langDir 'donate.json'
if (Test-Path $donateJson) {
    $donate = Get-Content -LiteralPath $donateJson -Raw -Encoding UTF8 | ConvertFrom-Json
    function LangLines([string]$code) {
        # Get-Content drops a UTF-8 BOM and the CR of CRLF files.
        return @(Get-Content -LiteralPath (Join-Path $langDir "$code.txt") -Encoding UTF8)
    }

    Check "Lang files de, ja, zh-tw carry 962/963 in front of an unmoved 1003" {
        foreach ($code in 'de', 'ja', 'zh-tw') {
            $w = $donate.$code
            if (-not $w) { return "donate.json has no words for $code" }
            $l = LangLines $code
            $i = [array]::IndexOf($l, '962')
            if ($i -lt 1) { return "$code.txt has no 962 line" }
            # -cne: PowerShell's -ne ignores case, and a wrong capital is a wrong word.
            if ($l[$i + 1] -cne $w.donate) { return "$code.txt 962 is '$($l[$i + 1])', expected '$($w.donate)'" }
            if ($l[$i + 2] -ne '963') { return "$code.txt: 963 does not follow the 962 string" }
            if ($l[$i + 3] -cne $w.website) { return "$code.txt 963 is '$($l[$i + 3])', expected '$($w.website)'" }
            if ($l[$i + 4] -ne '1003') { return "$code.txt: the explicit 1003 line is not right after 963" }
        }
    }

    Check "no Lang file's 962/963 string names 7-Zip" {
        $bad = New-Object System.Collections.Generic.List[string]
        foreach ($p in $donate.PSObject.Properties) {
            if ($p.Name -eq '_en') { continue }
            $l = LangLines $p.Name
            foreach ($id in '962', '963') {
                $i = [array]::IndexOf($l, $id)
                if ($i -lt 0) { $bad.Add("$($p.Name).txt has no $id line"); continue }
                if ($l[$i + 1] -match '7-Zip') { $bad.Add("$($p.Name).txt $id -> $($l[$i + 1])") }
            }
        }
        if ($bad.Count) { return ($bad -join '; ') }
    }
} else {
    # Not a SKIP: without donate.json nothing proves the buttons are translated,
    # and a missing file is exactly what a careless re-vendor of Lang\ produces.
    Check "Lang\donate.json exists (About-dialog button strings)" {
        return "missing: $donateJson"
    }
}

# --- donation address in the READMEs ---------------------------------------
#
# The English README.md sits at the repository root and the nine translations
# in docs\readme\ (moved there 2026-11-12), so links differ by directory:
# references are resolved against the file that holds them and compared as
# full paths, never as literal strings.
function Get-ReadmeFiles {
    $all = @(Get-Item -LiteralPath (Join-Path $RepoRoot 'README.md') -ErrorAction SilentlyContinue)
    $dir = Join-Path $RepoRoot 'docs\readme'
    if (Test-Path -LiteralPath $dir) {
        $all += @(Get-ChildItem -LiteralPath $dir -Filter 'README*.md' -File | Sort-Object Name)
    }
    return @($all | Where-Object { $_ })
}
function Get-LinkTargets([System.IO.FileInfo]$File, [string]$Text, [string]$LeafPattern) {
    # Link targets (markdown "](...)" and HTML src="...") whose last path
    # segment matches $LeafPattern, resolved to full paths. Anchors dropped.
    # Relative targets resolve against the file's own directory; a GitHub
    # "blob" URL into this repository (some READMEs link that way) resolves
    # against the repository root. Other absolute URLs are skipped.
    $out = @()
    foreach ($m in [regex]::Matches($Text, '(?:\]\(|src=")([^)"\s#]+)(?:#[^)"\s]*)?')) {
        $target = $m.Groups[1].Value
        if (($target -split '/')[-1] -notmatch $LeafPattern) { continue }
        $gh = [regex]::Match($target, '^https://github\.com/7zStar/7-ZSTar/blob/[^/]+/(.+)$')
        if ($gh.Success) {
            $out += [System.IO.Path]::GetFullPath((Join-Path $RepoRoot ($gh.Groups[1].Value -replace '/', '\')))
            continue
        }
        if ($target -match '^[a-zA-Z][a-zA-Z0-9+.-]*:') { continue }
        $out += [System.IO.Path]::GetFullPath((Join-Path $File.DirectoryName ($target -replace '/', '\')))
    }
    return $out
}
function Get-ReadmeLabel([System.IO.FileInfo]$File) {
    return $File.FullName.Substring($RepoRoot.Length).TrimStart('\')
}
#
# The wallet address is printed in every README and encoded in
# docs\donate-qr.png. Transfers cannot be reversed, nothing else in the build
# reads these files, and a typo in one copy (or a language added later with the
# address retyped by hand) would send the money somewhere else with a green
# build. This only proves the copies agree with each other and all point at the
# QR picture; it is not an EIP-55 checksum check (PowerShell has no keccak).
Check "all READMEs carry one identical donation address and the QR picture" {
    $readmes = Get-ReadmeFiles
    if ($readmes.Count -ne 10) { return "expected 10 READMEs (README.md + docs\readme\README*.md), found $($readmes.Count): $(($readmes | ForEach-Object { Get-ReadmeLabel $_ }) -join ', ')" }
    $qr = [System.IO.Path]::GetFullPath((Join-Path $RepoRoot 'docs\donate-qr.png'))
    if (-not (Test-Path -LiteralPath $qr) -or (Get-Item -LiteralPath $qr).Length -eq 0) { return "docs\donate-qr.png is missing or empty" }
    $addr = @{}
    foreach ($f in $readmes) {
        $t = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
        # [regex]::Matches is case-sensitive, and the capitals are the checksum.
        $m = [regex]::Matches($t, '0x[0-9a-fA-F]{40}')
        if ($m.Count -ne 1) { return "$(Get-ReadmeLabel $f) has $($m.Count) 0x addresses, expected exactly 1" }
        $qrRefs = @(Get-LinkTargets $f $t '^donate-qr\.png$')
        if (-not ($qrRefs -contains $qr)) { return "$(Get-ReadmeLabel $f) does not link docs\donate-qr.png (found: $($qrRefs -join ', '))" }
        $addr[$f.Name] = $m[0].Value
    }
    $ref = $readmes[0]
    $odd = @($readmes | Where-Object { -not ($addr[$_.Name] -ceq $addr[$ref.Name]) })
    if ($odd) { return "address differs from $($ref.Name) ($($addr[$ref.Name])) in: $(($odd.Name) -join ', ')" }
}

# --- README structure -------------------------------------------------------
#
# The ten READMEs are translations of one document, and nothing else in the
# build notices when one falls behind: three paragraphs added to README.md
# reached none of the seven newer translations until a manual audit found them.
# This compares counts only, so it says nothing about wording, but it catches a
# missing section, a missing link to docs\INSTALL.md and a language bar that was
# not extended when a language was added.
Check "all READMEs have the same section count, INSTALL.md link count and a ten-item language bar" {
    $readmes = Get-ReadmeFiles
    if ($readmes.Count -ne 10) { return "expected 10 READMEs (README.md + docs\readme\README*.md), found $($readmes.Count): $(($readmes | ForEach-Object { Get-ReadmeLabel $_ }) -join ', ')" }
    $install = [System.IO.Path]::GetFullPath((Join-Path $RepoRoot 'docs\INSTALL.md'))
    # The bar's separator is U+00B7; kept out of this file so it stays ASCII.
    $sep = [regex]::Escape(" $([char]0xB7) ")
    $stat = @{}
    foreach ($f in $readmes) {
        $t = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
        # A "## " line inside a code fence is not a section.
        $prose = [regex]::Replace($t, '(?s)```.*?```', '')
        $bar = @(@($t -split "`r?`n")[5] -split $sep).Count
        if ($bar -ne 10) { return "$(Get-ReadmeLabel $f) line 6 has $bar language-bar items, expected 10" }
        $stat[$f.Name] = @{
            Sections = [regex]::Matches($prose, '(?m)^## ').Count
            InstallLinks = @(Get-LinkTargets $f $prose '^INSTALL\.md$' | Where-Object { $_ -eq $install }).Count
        }
    }
    foreach ($what in 'Sections', 'InstallLinks') {
        # Compare with the most common value, so the file that is out of step is
        # the one named, not whichever sorts first.
        $common = ($readmes | Group-Object { $stat[$_.Name][$what] } | Sort-Object Count -Descending | Select-Object -First 1).Name
        $odd = @($readmes | Where-Object { "$($stat[$_.Name][$what])" -ne $common })
        if ($odd) {
            return "${what}: most READMEs have $common, but " + (($odd | ForEach-Object { "$($_.Name)=$($stat[$_.Name][$what])" }) -join ', ')
        }
    }
}

# --- licence documents -----------------------------------------------------
#
# NOTICE quotes each vendored library's copyright line from that library's own
# licence file. Re-vendoring an upstream release moves those lines - a year
# changes, a name is added - and nothing else in the build would notice: the
# code compiles, the tests pass, and the legal documents quietly start saying
# something the files do not. An audit found four such lines already wrong.
# Binding the two together here is the only cheap defence.
#
# Skipped when the sources are not present, so testing an unpacked release
# (-BinDir) still works.
$licenceQuotes = @(
    @{ Lib = 'zstd';       Src = 'C\zstd\LICENSE';       Line = 'Copyright (c) Meta Platforms, Inc. and affiliates.' }
    @{ Lib = 'xxHash';     Src = 'C\hashes\xxhash.h';    Line = 'Copyright (C) 2012-2023 Yann Collet' }
    @{ Lib = 'brotli';     Src = 'C\brotli\LICENSE';     Line = 'Copyright (c) 2009, 2010, 2013-2016 by the Brotli Authors.' }
    @{ Lib = 'lz4';        Src = 'C\lz4\LICENSE';        Line = 'Copyright (c) 2011-2020, Yann Collet' }
    @{ Lib = 'lz5';        Src = 'C\lz5\LICENSE';        Line = 'Copyright (c) 2011-2015, Yann Collet' }
    @{ Lib = 'lizard';     Src = 'C\lizard\LICENSE';     Line = 'Copyright (C) 2016-2017, Przemyslaw Skibinski' }
    @{ Lib = 'fast-lzma2'; Src = 'C\fast-lzma2\LICENSE'; Line = 'Copyright 2018-present Conor McCarthy' }
    @{ Lib = 'zstdmt';     Src = 'C\zstdmt\LICENSE';     Line = 'Copyright (c) 2016 - 2017, Tino Reichardt' }
)
$noticePath = Join-Path $RepoRoot 'NOTICE'
$haveSources = (Test-Path (Join-Path $RepoRoot 'C\zstd\LICENSE')) -and (Test-Path $noticePath)

if ($haveSources) {
    # Both sides are wrapped prose - NOTICE wraps to fit its column, licence
    # files wrap to theirs - so compare with whitespace flattened. Otherwise
    # the check would be a formatting rule rather than a content one, and
    # rewrapping a paragraph would "fail" a document that says the right thing.
    function Flat([string]$s) { ($s -replace '\s+', ' ').Trim() }
    $noticeFlat = Flat (Get-Content $noticePath -Raw)

    # Without this line Windows 11 shows the 7-ZSTar submenu twice under "Show more
    # options", and a merge taking upstream's GetState builds and tests green.
    # Whether the hiding still works can only be seen in the menu: MAINTAINING.md
    # Part 3.12.
    Check "packaged menu root still hides itself from the classic menu" {
        $src = Join-Path $RepoRoot 'CPP\7zip\UI\Explorer\ContextMenu.cpp'
        if (-not (Select-String -LiteralPath $src -SimpleMatch 'ECS_HIDDEN :' -Quiet)) {
            return 'GetState in ContextMenu.cpp no longer sets ECS_HIDDEN'
        }
    }

    # The live text of a C++ file. The email defaults in ZipRegistry.cpp are
    # upstream's commented-out lines switched on, so a merge that restores the
    # comment leaves the same words in the file and only this can tell them apart.
    function LiveCode([string]$rel) {
        $text = Get-Content (Join-Path $RepoRoot $rel) -Raw
        ($text -replace '(?s)/\*.*?\*/', '') -replace '//[^\r\n]*', ''
    }

    Check "context menu still has the one-step tar.zst item" {
        $live = LiveCode 'CPP\7zip\UI\Explorer\ContextMenu.cpp'
        if (-not $live.Contains('CMD_REC( kCompressToTarZst')) {
            return 'ContextMenu.cpp has no live CMD_REC for kCompressToTarZst'
        }
        # Without the case the item does nothing when clicked.
        if ($live -notmatch 'case\s+kCompressToTarZst\s*:') {
            return 'ContextMenu.cpp has no case for kCompressToTarZst in InvokeCommandCommon'
        }
        # Without this, selecting 16 or more items (either menu) writes a name with no extension.
        if (-not $live.Contains('cmdID == kCompressToTarZst')) {
            return 'ContextMenu.cpp no longer sets the .tar.zst postfix'
        }
    }

    Check "email items still default to off" {
        $live = LiveCode 'CPP\7zip\UI\Common\ZipRegistry.cpp'
        $off = @('kCompressEmail', 'kCompressTo7zEmail', 'kCompressToZipEmail' |
                 Where-Object { -not $live.Contains("& ~NContextMenuFlags::$_") })
        if ($off) { return "not masked in ZipRegistry.cpp: $($off -join ', ')" }
    }

    Check "NOTICE quotes every vendored licence file accurately" {
        $bad = @()
        foreach ($q in $licenceQuotes) {
            $src = Join-Path $RepoRoot $q.Src
            if (-not (Test-Path $src)) { $bad += "$($q.Lib): $($q.Src) is missing"; continue }
            $want = Flat $q.Line
            if (-not (Flat (Get-Content $src -Raw)).Contains($want)) {
                $bad += "$($q.Lib): not in $($q.Src) - '$want'"
            }
            elseif (-not $noticeFlat.Contains($want)) {
                $bad += "$($q.Lib): in the licence file but not in NOTICE - '$want'"
            }
        }
        if ($bad) { return ($bad -join "; ") }
    }

    # The claim "no GPL-licensed file is compiled into 7-ZSTar" rests on the
    # vendored trees being library-only. lz4 and lizard put GPL terms on their
    # programs/ and tests/ trees upstream, so a re-vendor that copied more than
    # the library would break that claim without any other symptom.
    Check "vendored libraries are library-only (no GPL programs/tests trees)" {
        $found = @()
        foreach ($d in 'zstd', 'hashes', 'brotli', 'lz4', 'lz5', 'lizard', 'fast-lzma2', 'zstdmt') {
            foreach ($sub in 'programs', 'tests') {
                if (Test-Path (Join-Path $RepoRoot "C\$d\$sub")) { $found += "C\$d\$sub" }
            }
        }
        if ($found) { return "GPL-bearing trees present: " + ($found -join ', ') }
    }

    # NOTICE states how many C++ files were ported from mcmilk/7-Zip-zstd, and
    # that number is an attribution claim, not trivia. It was wrong once: the
    # documents said 27, counted with a grep for "7-Zip-zstd" that also matched
    # our own files naming mcmilk to explain coder-id compatibility. Bind the
    # stated number to the files that actually carry the ported-from header.
    Check "NOTICE's count of ported files matches the files themselves" {
        $ported = @(Get-ChildItem (Join-Path $RepoRoot 'CPP') -Recurse -File -Include *.cpp, *.h |
                    Where-Object { (Get-Content $_.FullName -Raw) -match 'Ported from mcmilk/7-Zip-zstd' })
        if (-not ($noticeFlat -match '(\d+) encoder, decoder and handler files')) {
            return "NOTICE no longer states a ported-file count in the expected form"
        }
        $stated = [int]$Matches[1]
        if ($ported.Count -ne $stated) {
            return "NOTICE says $stated ported files; $($ported.Count) carry the header"
        }
    }

    # Upstream's binary licence obliges us to carry it: "Redistributions in
    # binary form must reproduce related license information from this file."
    Check "upstream's own licence statement ships with the package" {
        $up = Join-Path $RepoRoot 'LICENSE-7-Zip.txt'
        if (-not (Test-Path $up)) { return "LICENSE-7-Zip.txt is missing from the repository root" }
        # The whole sentence, not a prefix: "Redistributions in binary form
        # must reproduce" also opens clause 2 of both BSD licences quoted
        # later in the same file, so a prefix match would pass even with
        # upstream's own obligation deleted.
        $t = Get-Content $up -Raw
        if (-not (Flat $t).Contains('Redistributions in binary form must reproduce related license information from this file.')) {
            return "LICENSE-7-Zip.txt does not carry upstream's reproduction clause"
        }
        if (-not $t.Contains('All other files: the "GNU LGPL".')) {
            return "LICENSE-7-Zip.txt does not carry the clause covering Lang\ and the .chm"
        }
    }
} else {
    Write-Host "  SKIP  licence document checks (vendored sources not in $RepoRoot)"
}

# --- format registry -------------------------------------------------------

$formatInfo = (Sz @('i')).Out

# Isolate the Formats block. Column positions are not parsed: `7z i` prints a
# leading offset column and a variable-width flags column, and their exact
# shape differs between the standalone and 7z.dll-backed builds - so match on
# word boundaries within the block instead. \blz4\b does not match inside
# "tlz4", which is the distinction that matters here.
$formatsBlock = ($formatInfo -split "(?m)^Formats:")[-1] -split "(?m)^[A-Za-z]" | Select-Object -First 1

Check "codecs 7-ZSTar adds are all registered" {
    $missing = @()
    foreach ($f in 'zstd', 'brotli', 'lz4', 'lz5', 'lizard') {
        if ($formatsBlock -notmatch "\b$f\b") { $missing += $f }
    }
    if ($missing) { return "not registered: $($missing -join ', ')" }
}

Check "chained tar.* out-formats are registered" {
    $missing = @()
    foreach ($f in 'tar\.zst', 'tar\.br', 'tar\.gz', 'tar\.bz2', 'tar\.xz',
                   'tar\.lz4', 'tar\.lz5', 'tar\.liz') {
        if ($formatInfo -notmatch $f) { $missing += ($f -replace '\\', '') }
    }
    if ($missing) { return "not registered: $($missing -join ', ')" }
}

# kNumArcsMax in CPP/7zip/UI/Common/LoadCodecs.h - raised from 72 to 96 in M4.
# The table silently stops accepting registrations once full, so this asserts
# headroom rather than an exact count.
$FormatCeiling = 96
# Well below the ~73 currently registered: this end catches a build that
# links almost no format handlers, not a small drift.
$FormatFloor = 60

Check "format count is under the compiled-in ceiling ($FormatCeiling)" {
    $lines = ($formatInfo -split "`n")
    $start = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^Formats:') { $start = $i; break }
    }
    if ($start -lt 0) { return "no 'Formats:' section in 7z i output" }
    $count = 0
    for ($i = $start + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*$' -or $lines[$i] -match '^[A-Z]') { break }
        $count++
    }
    Write-Host ("        ({0} formats registered)" -f $count)
    if ($count -lt $FormatFloor) { return "only $count formats registered - expected $FormatFloor+" }
    if ($count -ge $FormatCeiling) { return "$count formats - at or over the $FormatCeiling ceiling" }
}

# --- round trips -----------------------------------------------------------

$srcDir = Join-Path $Work 'src'
New-Item -ItemType Directory -Force $srcDir | Out-Null
# Mixed compressibility so codecs are actually exercised.
Set-Content (Join-Path $srcDir 'text.txt') (("the quick brown fox " * 500))
# Fixed seed: incompressible test data must be identical run to run, or a
# size-sensitive failure would reproduce only sometimes.
$rng = [System.Random]::new(20260805)
$bytes = New-Object byte[] 65536
$rng.NextBytes($bytes)
[System.IO.File]::WriteAllBytes((Join-Path $srcDir 'random.bin'), $bytes)
$expected = @{}
Get-ChildItem $srcDir -File | ForEach-Object { $expected[$_.Name] = Sha $_.FullName }

# Archive extension per format. This matters for more than tidiness:
#   * Single-member formats (.zst/.br/.lz4/...) do not record the original
#     file name - the extracted name is the archive name minus its extension,
#     so the archive must be "<name>.<ext>" for the round trip to reproduce it.
#   * brotli registers as extension-only-open (raw brotli has no signature),
#     so an archive not ending in .br cannot be opened at all.
$ArcExt = @{
    '7z' = '7z'; 'zip' = 'zip'; 'zstd' = 'zst'; 'brotli' = 'br'
    'lz4' = 'lz4'; 'lz5' = 'lz5'; 'lizard' = 'liz'; 'xz' = 'xz'
    'gzip' = 'gz'; 'bzip2' = 'bz2'
}

foreach ($fmt in '7z', 'zip', 'zstd', 'brotli', 'lz4', 'lz5', 'lizard', 'xz', 'gzip', 'bzip2') {
    Check "round trip: -t$fmt" {
        # Single-file formats cannot hold two members; give them one file.
        $single = $fmt -notin @('7z', 'zip')
        $inputs = if ($single) { @('text.txt') } else { @('text.txt', 'random.bin') }
        $arc = if ($single) {
            Join-Path $Work "text.txt.$($ArcExt[$fmt])"
        } else {
            Join-Path $Work "rt-$fmt.$($ArcExt[$fmt])"
        }
        $outDir = Join-Path $Work "rt-$fmt-out"

        Push-Location $srcDir
        try {
            $tArg = "-t$fmt"
            $a = Sz (@('a', $tArg, $arc) + $inputs)
            if ($a.Code -ne 0) { return "compress failed: " + $a.Out }
            $x = Sz @('x', $arc, "-o$outDir", '-y')
            if ($x.Code -ne 0) { return "extract failed: " + $x.Out }
        } finally { Pop-Location }

        foreach ($n in $inputs) {
            $got = Join-Path $outDir $n
            if (-not (Test-Path $got)) { return "missing after extract: $n" }
            if ((Sha $got) -ne $expected[$n]) { return "hash mismatch: $n" }
        }
    }
}

# --- one-step chained archives --------------------------------------------

foreach ($fmt in 'tar.zst', 'tar.br', 'tar.gz', 'tar.bz2', 'tar.xz',
                 'tar.lz4', 'tar.lz5', 'tar.liz') {
    Check "one-step create + drill-down: $fmt" {
        $arc = Join-Path $Work "chain.$fmt"
        $outDir = Join-Path $Work ("chain-" + ($fmt -replace '\.', '_') + "-out")

        Push-Location $srcDir
        try {
            $tArg = "-t$fmt"
            $a = Sz @('a', $tArg, $arc, 'text.txt', 'random.bin')
            if ($a.Code -ne 0) { return "compress failed: " + $a.Out }
            if (-not (Test-Path $arc)) { return "archive not created" }

            # The point of the feature: listing must show the tar members, not
            # a single .tar entry.
            $l = Sz @('l', $arc)
            if ($l.Out -notmatch 'text\.txt' -or $l.Out -notmatch 'random\.bin') {
                return "no drill-down - listing showed a bare .tar instead of its contents"
            }
            $x = Sz @('x', $arc, "-o$outDir", '-y')
            if ($x.Code -ne 0) { return "extract failed: " + $x.Out }
        } finally { Pop-Location }

        foreach ($n in 'text.txt', 'random.bin') {
            $got = Join-Path $outDir $n
            if (-not (Test-Path $got)) { return "missing after extract: $n" }
            if ((Sha $got) -ne $expected[$n]) { return "hash mismatch: $n" }
        }
    }
}

# --- interop with an independent implementation ---------------------------

$bsdtar = Join-Path $env:WINDIR 'System32\tar.exe'
if (Test-Path $bsdtar) {
    Check "interop: bsdtar reads our tar.gz" {
        $arc = Join-Path $Work 'interop-ours.tar.gz'
        Push-Location $srcDir
        try {
            $tArg = '-ttar.gz'
            $a = Sz @('a', $tArg, $arc, 'text.txt')
            if ($a.Code -ne 0) { return "compress failed: " + $a.Out }
        } finally { Pop-Location }

        $outDir = Join-Path $Work 'interop-ours-out'
        New-Item -ItemType Directory -Force $outDir | Out-Null
        & $bsdtar -xf $arc -C $outDir 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { return "bsdtar could not read our archive" }
        $got = Join-Path $outDir 'text.txt'
        if (-not (Test-Path $got)) { return "bsdtar produced no file" }
        if ((Sha $got) -ne $expected['text.txt']) { return "hash mismatch after bsdtar extract" }
    }

    Check "interop: we drill into bsdtar's tar.gz" {
        $arc = Join-Path $Work 'interop-theirs.tar.gz'
        & $bsdtar -czf $arc -C $srcDir 'text.txt' 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { return "bsdtar could not create the archive" }
        $l = Sz @('l', $arc)
        if ($l.Out -notmatch 'text\.txt') { return "no drill-down into bsdtar's archive" }
    }
} else {
    Write-Host "  SKIP  interop tests (System32\tar.exe not present)"
}

# --- non-tar regression ----------------------------------------------------

Check "non-tar .zst still lists as a single item (drill-down does not misfire)" {
    $arc = Join-Path $Work 'plain.zst'
    Push-Location $srcDir
    try {
        $tArg = '-tzstd'
        $a = Sz @('a', $tArg, $arc, 'random.bin')
        if ($a.Code -ne 0) { return "compress failed: " + $a.Out }
    } finally { Pop-Location }
    $l = Sz @('l', $arc)
    if ($l.Out -match 'text\.txt') { return "unexpected drill-down into a non-tar payload" }
}

# --- brotli raw/mt-container content detection ------------------------------
# The mcmilk wire format wraps multi-threaded brotli output in a private
# skippable-frame container; raw brotli has no signature at all. The decoder
# tells them apart by reading the container's whole 16-byte first frame
# header (7-ZSTar hardening of the upstream issue #538 fix). All inputs are
# committed vectors from build\testdata\ (see the README there) -
# deliberately no byte-writing here: a script that drops binary blobs and
# immediately runs a tool on them is exactly the shape AV heuristics
# quarantine, and this suite lost its first version of these checks to that.
# What they pin:
#   * genuine mcmilk containers keep decoding with no -mmt anywhere,
#   * anything failing any part of the 16-byte check decodes as raw
#     brotli, and failures say "Data Error" - never "Unspecified error"
#     (the pre-hardening container-path error),
#   * and detection can still be overridden, by an explicit -mmt=0.

$brData = Join-Path $PSScriptRoot 'testdata'
# SHA-256 of mt-brotli.br's 200000-byte payload (brdetect.c make_payload).
$brVectorPayloadSha = '0361E377A4D5213E4D2A7584912230EF7D706ECFFC59A486EC8BE53C7FA92EAF'

if (Test-Path (Join-Path $brData 'mt-brotli.br')) {
    Check "mt-brotli container (mcmilk wire format) extracts without -mmt" {
        $outDir = Join-Path $Work 'brmt-out'
        $x = Sz @('x', (Join-Path $brData 'mt-brotli.br'), "-o$outDir", '-y')
        if ($x.Code -ne 0) { return "extract failed: " + $x.Out }
        $got = Join-Path $outDir 'mt-brotli'
        if (-not (Test-Path $got)) { return "no output file" }
        if ((Sha $got) -ne $brVectorPayloadSha) { return "payload hash mismatch" }
    }

    foreach ($v in @(
        @{ Name = 'corrupt-hdr.br'; What = 'corrupted mt-brotli header' },
        @{ Name = 'fake-magic.br';  What = 'raw .br faking the container magic' }
    )) {
        Check "$($v.What) fails as Data Error, not Unspecified" {
            $t = Sz @('t', (Join-Path $brData $v.Name))
            if ($t.Code -eq 0) { return "bad input unexpectedly passed" }
            if ($t.Out -match 'Unspecified') { return "regressed to Unspecified error" }
            if ($t.Out -notmatch 'Data Error') { return "expected Data Error, got: " + $t.Out }
        }
    }
    # --- the -mmt=0 escape hatch out of content detection -------------------
    # Detection replaced the old "threads == 0 means raw" selector, so without
    # a hatch a raw stream that ever collided with the 16-byte container
    # header would be unreadable by any means - and a signature-less format
    # cannot be detected with certainty however wide the probe. An explicit
    # -mmt=0 forces the raw decoder and skips detection entirely.
    #
    # Only that spelling. Official 7-Zip's ParseMtProp2() maps -mmt=off and
    # -mmt- onto a forced count of 1, indistinguishable from -mmt=1 by the
    # time the handler sees it, so honouring those would stop -mmt=1 from
    # reading 7-Zip ZS's mt containers - likelier to bite someone capping CPU
    # than the collision being guarded against. The second check below pins
    # exactly that: those three spellings must keep working.
    #
    # The container vector is what gives the first check teeth. Asserting
    # only that raw brotli still decodes under -mmt=0 would pass just as well
    # with no hatch at all, since detection sends raw brotli to the raw
    # decoder anyway; requiring the container to *stop* decoding is what
    # shows the flag really overrides detection.
    $brSrc = Join-Path $Work 'hatch-src.txt'
    Set-Content -LiteralPath $brSrc -Value (('7-ZSTar brotli escape hatch. ' * 400)) -NoNewline
    $brSrcSha = Sha $brSrc
    $brRaw = Join-Path $Work 'hatch.br'
    $mkRaw = Sz @('a', '-tbrotli', $brRaw, $brSrc)

    Check "-mmt=0 forces raw decoding: bytes unchanged, container refused" {
        if ($mkRaw.Code -ne 0) { return "could not build the raw .br: " + $mkRaw.Out }
        # lossless on a stream that was raw all along: every probed byte is
        # handed back, so reaching for the hatch costs nothing
        $outDir = Join-Path $Work 'hatch-out'
        $x = Sz @('x', $brRaw, "-o$outDir", '-y', '-mmt=0')
        if ($x.Code -ne 0) { return "-mmt=0 failed on raw brotli: " + $x.Out }
        $got = Join-Path $outDir 'hatch'
        if (-not (Test-Path $got)) { return "-mmt=0 produced no output file" }
        if ((Sha $got) -ne $brSrcSha) { return "-mmt=0 changed the bytes" }
        # ...and it really did bypass detection
        $t = Sz @('t', (Join-Path $brData 'mt-brotli.br'), '-mmt=0')
        if ($t.Code -eq 0) { return "-mmt=0 still decoded the mt container" }
        if ($t.Out -match 'Unspecified') { return "-mmt=0 reported Unspecified error" }
    }

    Check "every other -mmt spelling leaves detection alone" {
        if ($mkRaw.Code -ne 0) { return "could not build the raw .br: " + $mkRaw.Out }
        foreach ($flag in '-mmt', '-mmt+', '-mmt=on', '-mmt=off', '-mmt-', '-mmt=1', '-mmt=4') {
            $t = Sz @('t', $brRaw, $flag)
            if ($t.Code -ne 0) { return "$flag broke raw brotli: " + $t.Out }
            $t = Sz @('t', (Join-Path $brData 'mt-brotli.br'), $flag)
            if ($t.Code -ne 0) { return "$flag broke the mt container: " + $t.Out }
        }
    }

    # Brotli inside a .7z is always written as an mt container, and .7z
    # extraction runs the decoder through 7zDecode.cpp, which never sets the
    # hatch - only the standalone .br handler does. So -mmt=0 must not reach
    # in there and break the container. This is the regression sebres'
    # bcf9049b fixes in mcmilk/7-Zip-zstd; here the wiring rules it out by
    # construction, which is worth a test precisely because nothing in the
    # .br code path would notice if that stopped being true.
    Check "-mmt=0 does not reach brotli inside a .7z" {
        $sevenZ = Join-Path $Work 'hatch-in-7z.7z'
        $a = Sz @('a', '-t7z', '-m0=brotli', $sevenZ, $brSrc)
        if ($a.Code -ne 0) { return "could not build the .7z: " + $a.Out }
        $outDir = Join-Path $Work 'hatch7z-out'
        $x = Sz @('x', $sevenZ, "-o$outDir", '-y', '-mmt=0')
        if ($x.Code -ne 0) { return "-mmt=0 broke .7z extraction: " + $x.Out }
        $got = Join-Path $outDir (Split-Path $brSrc -Leaf)
        if ((Sha $got) -ne $brSrcSha) { return "-mmt=0 changed the bytes" }
    }

    # The hatch is set on all three decoders one .br open creates, including
    # the throwaway one that sniffs for a tar. If they ever disagreed, a
    # .tar.br could sniff as a tar and then fail to extract - so pin that the
    # drill-down still works with the hatch on. (What this cannot pin is the
    # disagreement itself: every .tar.br this project writes is raw brotli,
    # so both routings reach the same answer for it, and the file that would
    # separate them is the collision nobody has been able to construct.)
    Check "-mmt=0 does not break .tar.br drill-down" {
        $tdir = Join-Path $Work 'hatch-tar'
        New-Item -ItemType Directory -Force $tdir | Out-Null
        Set-Content -LiteralPath (Join-Path $tdir 'inner-a.txt') -Value 'alpha'
        Set-Content -LiteralPath (Join-Path $tdir 'inner-b.txt') -Value 'beta'
        $tbr = Join-Path $Work 'hatch-drill.tar.br'
        $tfmt = '-ttar.br'
        $a = Sz @('a', $tfmt, $tbr, (Join-Path $tdir 'inner-a.txt'), (Join-Path $tdir 'inner-b.txt'))
        if ($a.Code -ne 0) { return "could not build the .tar.br: " + $a.Out }
        foreach ($flag in '-mmt=0', '-mmt=4') {
            $l = Sz @('l', $tbr, $flag)
            if ($l.Code -ne 0) { return "$flag failed to list: " + $l.Out }
            foreach ($n in 'inner-a.txt', 'inner-b.txt') {
                if ($l.Out -notmatch [regex]::Escape($n)) {
                    return "$flag listed the .tar instead of drilling in: " + $l.Out
                }
            }
        }
    }
} else {
    Write-Host "  SKIP  brotli detection vectors (build\testdata not present)"
}

# --- truncated lz4 / lz5 / lizard / brotli streams --------------------------
# A file cut short has to say so: "Unexpected end of data". Before mcmilk
# #564 was ported, lz4/lz5/lizard said E_FAIL's "Unspecified error" and
# brotli "Data Error". The vectors are committed for the same reason as the
# brotli ones above; testdata\README.md says which zstdmt read path each one
# reaches (each codec has its own plain-stream and container path).
foreach ($v in 'trunc.lz4', 'trunc.lz5', 'trunc.liz', 'trunc.br', 'trunc-prefix.br', 'trunc-mt.br') {
    Check "truncated $v fails as Unexpected end of data" {
        $p = Join-Path $PSScriptRoot "testdata\$v"
        if (-not (Test-Path $p)) { return "vector missing: $p" }
        $t = Sz @('t', $p)
        if ($t.Code -eq 0) { return "truncated input unexpectedly passed" }
        if ($t.Out -match 'Unspecified') { return "regressed to Unspecified error" }
        if ($t.Out -notmatch 'Unexpected end of data') {
            return "expected Unexpected end of data, got: " + $t.Out
        }
    }
}

# A plain brotli stream cut short still has to fail, but only after handing
# over what decoded before the cut. When the input ends that data sits in two
# places: the 1 MiB output buffer and, past it, brotli's ring buffer
# (st_drain_output() in C/zstdmt/brotli-mt_decompress.c). This vector decodes
# to almost 2 MB, so more than 1 MiB out means the ring buffer was drained too.
# That 1 MiB is st_decompress()'s ctx->inputsize * 4, with the 256 KiB default
# from BROTLIMT_createDCtx(); if it grows past 2 MB, this check needs a larger
# vector. The expected text is built here; no binary is written
# (testdata\README.md).
Check "truncated trunc-prefix.br keeps its decoded prefix and still fails" {
    $p = Join-Path $PSScriptRoot 'testdata\trunc-prefix.br'
    if (-not (Test-Path $p)) { return "vector missing: $p" }
    $outDir = Join-Path $Work 'x-trunc-prefix'
    $x = Sz @('x', $p, "-o$outDir", '-y')
    if ($x.Code -ne 2) { return "expected exit code 2, got $($x.Code): " + $x.Out }
    if ($x.Out -notmatch 'Unexpected end of data') {
        return "expected Unexpected end of data, got: " + $x.Out
    }
    $got = Join-Path $outDir 'trunc-prefix'
    if (-not (Test-Path $got)) { return "nothing extracted" }
    $have = [IO.File]::ReadAllText($got)
    if ($have.Length -le 1MB) {
        return "only $($have.Length) bytes decoded - the ring buffer was not drained"
    }
    $want = ((0..99999 | ForEach-Object { '7-ZSTar truncation vector line {0:d5}' -f $_ }) -join "`n") + "`n"
    if ($have.Length -ge $want.Length) { return "decoded the whole payload from a cut stream" }
    if (-not $want.StartsWith($have, [StringComparison]::Ordinal)) {
        return "the $($have.Length) decoded bytes are not a prefix of the payload"
    }
    Write-Host ("        (decoded {0} of {1} bytes)" -f $have.Length, $want.Length)
}

# A .tar.* cut off after its first compressed unit takes another path: the
# tar sniff succeeds, the drill-down's decode-to-temp-file then fails and
# leaves the shared stream at EOF, and 7-Zip falls back to extracting the
# .tar as a single file. Extract() used to start from that EOF: nothing
# extracted, "Data Error". It rewinds now, so the error is the real one and
# the fallback writes what decoded - the second half of the check, which
# fails for any of the four handlers if its rewind is dropped. For brotli
# it is the only half that does: from EOF its raw decoder also ends in
# end_of_data. trunc.tar.br comes from a much larger payload, because a 60%
# cut of the smaller one decodes nothing under brotli (testdata\README.md).
foreach ($v in 'trunc.tar.lz4', 'trunc.tar.lz5', 'trunc.tar.liz', 'trunc.tar.br') {
    Check "truncated $v falls back to a partial .tar, Unexpected end of data" {
        $p = Join-Path $PSScriptRoot "testdata\$v"
        if (-not (Test-Path $p)) { return "vector missing: $p" }
        $t = Sz @('t', $p)
        if ($t.Code -eq 0) { return "truncated input unexpectedly passed" }
        if ($t.Out -notmatch 'Unexpected end of data') {
            return "expected Unexpected end of data, got: " + $t.Out
        }
        $outDir = Join-Path $Work ("x-" + $v)
        $null = Sz @('x', $p, "-o$outDir", '-y')
        $got = Join-Path $outDir 'trunc.tar'
        if (-not (Test-Path $got)) { return "no .tar written by the fallback" }
        if ((Get-Item $got).Length -lt 512) {
            return "fallback wrote $((Get-Item $got).Length) bytes - Extract() did not start from the beginning"
        }
    }
}

# --- corrupt lz4 / lz5 / lizard / brotli data inside a .7z ------------------
# One byte flipped mid-stream must report "Data Error". That is the decoders
# returning S_FALSE, 7-Zip's data-error result (#564 port, see
# Lz4Decoder.cpp). Before it lz4/lz5/lizard returned E_FAIL ("Unspecified
# error"), and mcmilk's own form of #564 returns Win32 codes as HRESULTs,
# which 7-Zip shows as Windows' "Reached the end of the file" - the
# regression a re-sync from mcmilk would bring back (MAINTAINING.md Part
# 2b). corrupt-lz4mt.7z is lz4 written with -mmt=2, i.e. as the container,
# which is what a .7z gets by default; brotli in a .7z is always one.
foreach ($v in 'corrupt-lz4.7z', 'corrupt-lz4mt.7z', 'corrupt-lz5.7z', 'corrupt-liz.7z', 'corrupt-br.7z') {
    Check "$v (one byte flipped) fails as Data Error" {
        $p = Join-Path $PSScriptRoot "testdata\$v"
        if (-not (Test-Path $p)) { return "vector missing: $p" }
        $t = Sz @('t', $p)
        if ($t.Code -eq 0) { return "corrupt input unexpectedly passed" }
        if ($t.Out -match 'Unspecified') { return "regressed to Unspecified error" }
        if ($t.Out -match 'end of the file') { return "Win32 code surfaced as an HRESULT: " + $t.Out }
        if ($t.Out -notmatch 'Data Error') { return "expected Data Error, got: " + $t.Out }
    }
}

# --- regression: header size field out of range -----------------------------
# Each vector is a valid lz4 / lz5 / lizard / brotli container with one
# frame-header size field set to 1 GiB, past the 256 MiB bound the decoders
# check before allocating (MT_FRAME_SIZE_MAX, C/zstdmt/memmt.h). It must fail
# as "Data Error" without the allocation: the peak commit charge has to stay
# under $peakLimitMB. 7z's own -bt statistics print it on exit, error or not,
# as "Virtual Memory" (PeakPagefileUsage, CPP/7zip/UI/Console/Main.cpp - the
# counter .NET calls PeakPagedMemorySize64). Unbounded, every vector peaked
# at ~1030 MB.
$peakLimitMB = 256
foreach ($v in 'oversize-packed-lz4mt.7z', 'oversize-content-lz4mt.7z',
               'oversize-packed.lz5', 'oversize-content.lz5',
               'oversize-packed.liz', 'oversize-content.liz',
               'oversize-packed-mt.br', 'oversize-hint-mt.br') {
    Check "$v fails as Data Error under $peakLimitMB MB" {
        $p = Join-Path $PSScriptRoot "testdata\$v"
        if (-not (Test-Path $p)) { return "vector missing: $p" }
        $t = Sz @('t', '-bt', $p)
        if ($t.Code -eq 0) { return "out-of-range header unexpectedly passed" }
        if ($t.Out -notmatch 'Virtual\s+Memory =\s*(\d+) MB') { return "no -bt memory statistics: " + $t.Out }
        $peakMB = [int]$Matches[1]
        Write-Host ("        (peak commit {0} MB)" -f $peakMB)
        if ($peakMB -gt $peakLimitMB) { return "peak commit $peakMB MB exceeds $peakLimitMB MB" }
        if ($t.Out -notmatch 'Data Error') { return "expected Data Error, got: " + $t.Out }
    }
}

# --- summary ---------------------------------------------------------------

Remove-Item $Work -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host ("{0} passed, {1} failed" -f $script:Pass, $script:Fail)
if ($script:Fail -gt 0) { exit 1 }
Write-Host "all smoke tests passed"

# Explicit, so the success path cannot inherit $LASTEXITCODE from the last
# native command run above - which is an intentionally-failing 7z invocation
# (the corrupt .7z vectors), leaving $LASTEXITCODE at 2 after a
# fully green run. `pwsh -File` / `pwsh -command ". script"` both return 0
# regardless, but any wrapper that propagates $LASTEXITCODE would read a
# passing run as a failure.
exit 0

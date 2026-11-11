# Tests for the build-artifact freshness check (build\SourceStamp.ps1 and
# build\Assert-Fresh.ps1).
#
#   pwsh build\Test-SourceStamp.ps1
#
# Builds a scratch git repository in %TEMP% (it never touches this one), puts
# a copy of the library into it, and drives build\Assert-Fresh.ps1 as a child
# process under both Windows PowerShell 5.1 and PowerShell 7 - the two hosts
# the packaging and test scripts run under. Every verdict is the child's EXIT
# CODE and nothing else: 0 = fresh, 1 = stale or unverifiable. Output text is
# printed only to explain a failure.
#
# Exits non-zero if any case fails.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$SelfDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

$hosts = [ordered]@{}
$ps51 = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
if (Test-Path $ps51) { $hosts['powershell 5.1'] = $ps51 }
$pwshCmd = Get-Command pwsh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($pwshCmd) { $hosts['pwsh 7'] = $pwshCmd.Source }
if ($hosts.Count -eq 0) { throw 'Neither powershell.exe nor pwsh was found.' }
if (-not (Get-Command git -CommandType Application -ErrorAction SilentlyContinue)) { throw 'git was not found on PATH.' }

$Work = Join-Path ([IO.Path]::GetTempPath()) ('7zstar-stamptest-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force $Work | Out-Null

$script:Pass = 0
$script:Fail = 0

function GitC([string[]]$GitArgs) {
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        # Overrides keep the scratch repo independent of the user's global git
        # config (commit signing, hooks, line-ending conversion).
        $out = & git -C $Work -c user.name=t -c user.email=t@example.invalid -c core.autocrlf=false `
            -c commit.gpgsign=false -c core.hooksPath=$Work\.nohooks @GitArgs 2>&1
        if ($LASTEXITCODE -ne 0) { throw "git $($GitArgs -join ' ') failed: $out" }
    } finally { $ErrorActionPreference = $prev }
}
function Put([string]$Rel, [string]$Text) {
    $p = Join-Path $Work $Rel
    New-Item -ItemType Directory -Force (Split-Path -Parent $p) | Out-Null
    [IO.File]::WriteAllText($p, $Text)
}
function PathOf([string]$Rel) { Join-Path $Work $Rel }

# Run Assert-Fresh.ps1 under one host; return the exit code. Output is kept for
# failure messages only.
$script:LastOutput = ''
function RunAssert([string]$HostExe, [string[]]$Artifacts, [switch]$Skip) {
    $argv = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (PathOf 'build\Assert-Fresh.ps1'),
              '-Path') + $Artifacts
    if ($Skip) { $argv += '-SkipFreshnessCheck' }
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { $script:LastOutput = (& $HostExe @argv 2>&1 | Out-String); $code = $LASTEXITCODE }
    finally { $ErrorActionPreference = $prev }
    return $code
}
# Stamp an artifact the way the real producers do, in a child process (so the
# stamp comes from a clean session, and from a chosen host).
function MakeStamp([string]$HostExe, [string]$Artifact, [string]$Kind) {
    $helper = PathOf 'build\_mkstamp.ps1'
    [IO.File]::WriteAllText($helper, @'
param($Artifact, $Kind)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'SourceStamp.ps1')
Write-SourceStamp -StampPath (Get-SourceStampPath $Artifact) -Fingerprint (Get-SourceFingerprint -Kind $Kind) -ArtifactFiles $Artifact
'@)
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        $out = & $HostExe -NoProfile -ExecutionPolicy Bypass -File $helper -Artifact $Artifact -Kind $Kind 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) { throw "stamping failed: $out" }
    } finally { $ErrorActionPreference = $prev }
}
function Expect([string]$Name, [int]$Want, [int]$Got) {
    if ($Want -eq $Got) {
        Write-Host "  PASS  $Name"
        $script:Pass++
    } else {
        Write-Host "  FAIL  $Name (want exit $Want, got $Got)"
        ($script:LastOutput -split "`n" | Select-Object -First 6 | ForEach-Object { "          $_" }) | Write-Host
        $script:Fail++
    }
}

try {
    # --- scratch repository ---------------------------------------------------
    GitC @('init', '-q')
    Put '.gitignore' "x64/`nbuild/logs/`ninstaller/dist/`n"
    Put 'C/a.c' "int a;`n"
    Put 'CPP/b.cpp' "int b;`n"
    Put 'Asm/c.asm' "nop`n"
    Put 'installer/7-ZSTar.wxs' "<Wix/>`n"
    Put 'installer/Test-x.ps1' "# test`n"
    Put 'installer/GUIDS.md' "notes`n"
    Put 'Lang/en.txt' "lang`n"
    Put 'Help/h.chm' "help`n"
    foreach ($d in 'LICENSE', 'COPYING', 'LICENSE-EXCEPTIONS.md', 'LICENSE-7-Zip.txt', 'NOTICE', 'README.md', 'CHANGELOG.md') {
        Put $d "$d`n"
    }
    Put 'docs/notes.md' "docs`n"
    New-Item -ItemType Directory -Force (PathOf 'build') | Out-Null
    Copy-Item (Join-Path $SelfDir 'SourceStamp.ps1') (PathOf 'build\SourceStamp.ps1')
    Copy-Item (Join-Path $SelfDir 'Assert-Fresh.ps1') (PathOf 'build\Assert-Fresh.ps1')
    GitC @('add', '-A')
    GitC @('commit', '-q', '-m', 'scratch')

    $exe = 'CPP\UI\Console\x64\7z.exe'      # a "built binary" (x64\ is ignored)
    $msi = 'installer\dist\pkg.msi'         # a "package"
    $log = PathOf 'build\logs\freshness-skips.log'
    function IndexHash { (Get-FileHash -LiteralPath (PathOf '.git\index') -Algorithm SHA256).Hash }

    foreach ($h in $hosts.GetEnumerator()) {
        $hn = $h.Key; $hx = $h.Value
        Write-Host "[$hn]"
        Put 'CPP/UI/Console/x64/7z.exe' "binary`n"
        MakeStamp $hx (PathOf $exe) 'binary'
        $a = @(PathOf $exe)

        # binary kind -------------------------------------------------------
        Expect "$hn fresh binary passes" 0 (RunAssert $hx $a)

        # A stamp written by the other host must read the same (5.1 <-> 7).
        $otherHost = @($hosts.Values | Where-Object { $_ -ne $hx })[0]
        if ($otherHost) {
            MakeStamp $otherHost (PathOf $exe) 'binary'
            Expect "$hn a stamp written by the other host is fresh" 0 (RunAssert $hx $a)
            MakeStamp $hx (PathOf $exe) 'binary'
        }

        # A relative path resolves against where the caller is, not the process directory.
        # (Assert-Fresh.ps1 makes paths absolute itself, which would hide the
        # defect; the scripts that call Assert-ArtifactFresh directly, such as
        # Test-MsiRegistry -Msi <relative>, do not - so call the library here.)
        [IO.File]::WriteAllText((PathOf 'build\_rel.ps1'), @'
param($Repo, $Rel)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'SourceStamp.ps1')
Set-Location -LiteralPath $Repo      # PowerShell's location moves; the process directory need not
Assert-ArtifactFresh -Path $Rel | Out-Null
exit 0
'@)
        $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        try {
            $script:LastOutput = (& $hx -NoProfile -ExecutionPolicy Bypass -File (PathOf 'build\_rel.ps1') -Repo $Work -Rel $exe 2>&1 | Out-String)
            $relCode = $LASTEXITCODE
        } finally { $ErrorActionPreference = $prev }
        Expect "$hn a relative artifact path after Set-Location is fresh" 0 $relCode

        # GIT_INDEX_FILE is the caller's again afterwards, set or not.
        [IO.File]::WriteAllText((PathOf 'build\_env.ps1'), @'
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'SourceStamp.ps1')
$env:GIT_INDEX_FILE = 'sentinel-index-value'
Get-SourceFingerprint -Kind binary | Out-Null
if ($env:GIT_INDEX_FILE -ne 'sentinel-index-value') { exit 3 }
Remove-Item Env:\GIT_INDEX_FILE
Get-SourceFingerprint -Kind binary | Out-Null
if (Test-Path Env:\GIT_INDEX_FILE) { exit 4 }
exit 0
'@)
        $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        try { $script:LastOutput = (& $hx -NoProfile -ExecutionPolicy Bypass -File (PathOf 'build\_env.ps1') 2>&1 | Out-String); $envCode = $LASTEXITCODE }
        finally { $ErrorActionPreference = $prev }
        Expect "$hn GIT_INDEX_FILE is restored (set and unset)" 0 $envCode

        Remove-Item (PathOf 'CPP\b.cpp') -Force
        Expect "$hn a deleted tracked source file is stale" 1 (RunAssert $hx $a)
        GitC @('checkout', '--', 'CPP/b.cpp')
        Expect "$hn deleted file restored is fresh again" 0 (RunAssert $hx $a)

        Put 'CPP/b.cpp' "int b = 2;`n"
        $idxBefore = IndexHash
        Expect "$hn uncommitted source edit is stale" 1 (RunAssert $hx $a)
        Expect "$hn the check leaves the real git index alone" 0 $(if ($idxBefore -eq (IndexHash)) { 0 } else { 1 })
        Put 'CPP/b.cpp' "int b;`n"
        Expect "$hn edit reverted is fresh again" 0 (RunAssert $hx $a)

        Put 'CPP/new.cpp' "int n;`n"
        Expect "$hn new untracked source file is stale" 1 (RunAssert $hx $a)
        Remove-Item (PathOf 'CPP\new.cpp') -Force
        Expect "$hn untracked file removed is fresh again" 0 (RunAssert $hx $a)

        Put 'docs/notes.md' "docs changed`n"
        Expect "$hn documentation-only change stays fresh" 0 (RunAssert $hx $a)
        Put 'CPP/UI/Console/x64/junk.obj' "obj`n"
        Expect "$hn ignored build output stays fresh" 0 (RunAssert $hx $a)
        Put 'README.md' "readme changed`n"
        Expect "$hn README change does not stale a binary" 0 (RunAssert $hx $a)
        Put 'README.md' "README.md`n"

        Put 'C/a.c' "int a = '$hn';`n"   # differs per host, so there is always something to commit
        GitC @('add', '-A'); GitC @('commit', '-q', '-m', 'edit after build')
        Expect "$hn committed edit after the build is stale" 1 (RunAssert $hx $a)
        MakeStamp $hx (PathOf $exe) 'binary'
        Expect "$hn restamped after the edit is fresh" 0 (RunAssert $hx $a)

        # a stamp that cannot be trusted -------------------------------------
        $stampFile = PathOf 'CPP\UI\Console\x64\.srcstamp'
        $saved = [IO.File]::ReadAllText($stampFile)
        Remove-Item $stampFile -Force
        Expect "$hn missing stamp is refused" 1 (RunAssert $hx $a)

        if (Test-Path $log) { Remove-Item $log -Force }
        Expect "$hn -SkipFreshnessCheck lets the unstamped one through" 0 (RunAssert $hx $a -Skip)
        $logged = (Test-Path $log) -and ((Get-Content $log -Raw) -match [regex]::Escape('7z.exe'))
        Expect "$hn the skip is written to freshness-skips.log" 0 $(if ($logged) { 0 } else { 1 })

        [IO.File]::WriteAllText($stampFile, '{not json')
        Expect "$hn corrupt stamp is refused" 1 (RunAssert $hx $a)
        # Exit 1 is a verdict; a crash in the check would be 2, which these cases would catch.
        [IO.File]::WriteAllText($stampFile, '{"kind":"binary","fingerprint":"abc"}')
        Expect "$hn stamp with a malformed fingerprint is refused (verdict, not a crash)" 1 (RunAssert $hx $a)
        [IO.File]::WriteAllText($stampFile, '{"kind":"binary","fingerprint":"' + ('0' * 64) + '","artifacts":{}}')
        Expect "$hn stamp with a well-formed but wrong fingerprint is refused" 1 (RunAssert $hx $a)
        [IO.File]::WriteAllText($stampFile, $saved)
        Expect "$hn stamp restored is fresh" 0 (RunAssert $hx $a)

        # Judged by content, not by time: a bare touch changes nothing...
        (Get-Item (PathOf $exe)).LastWriteTime = (Get-Date).AddMinutes(5)
        Expect "$hn touching the artifact (same bytes) is fine" 0 (RunAssert $hx $a)
        # ...and an old file copied back with its old mtime kept is still caught.
        $origBytes = [IO.File]::ReadAllBytes((PathOf $exe))
        $origTime = (Get-Item (PathOf $exe)).LastWriteTime
        [IO.File]::WriteAllBytes((PathOf $exe), [Text.Encoding]::ASCII.GetBytes("OLD binary`n"))
        (Get-Item (PathOf $exe)).LastWriteTime = $origTime.AddDays(-3)
        Expect "$hn different bytes under an old mtime are refused" 1 (RunAssert $hx $a)
        [IO.File]::WriteAllBytes((PathOf $exe), $origBytes)
        Expect "$hn original bytes back is fresh again" 0 (RunAssert $hx $a)
        Put 'CPP/UI/Console/x64/other.exe' "not built by the stamped build`n"
        Expect "$hn a file the stamp does not list is refused" 1 (RunAssert $hx @(PathOf 'CPP\UI\Console\x64\other.exe'))
        Remove-Item (PathOf 'CPP\UI\Console\x64\other.exe') -Force

        # A long-lived process must not keep an old verdict after the source changes.
        [IO.File]::WriteAllText((PathOf 'build\_cache.ps1'), @'
param($Artifact)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'SourceStamp.ps1')
Assert-ArtifactFresh -Path $Artifact | Out-Null          # fresh: must not throw
Add-Content -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) 'CPP\b.cpp') -Value '// edited mid-process'
try { Assert-ArtifactFresh -Path $Artifact | Out-Null; exit 2 } catch { exit 0 }   # must throw now
'@)
        $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        try { $script:LastOutput = (& $hx -NoProfile -ExecutionPolicy Bypass -File (PathOf 'build\_cache.ps1') -Artifact (PathOf $exe) 2>&1 | Out-String); $cc = $LASTEXITCODE }
        finally { $ErrorActionPreference = $prev }
        Expect "$hn same process: check, edit source, check again is refused" 0 $cc
        GitC @('checkout', '--', 'CPP/b.cpp')

        Expect "$hn missing artifact is refused" 1 (RunAssert $hx @(PathOf 'CPP\UI\Console\x64\nope.exe'))
        Expect "$hn one stale among several refuses the lot" 1 (RunAssert $hx @($a[0], (PathOf 'CPP\UI\Console\x64\nope.exe')))

        # package kind --------------------------------------------------------
        Put 'installer/dist/pkg.msi' "msi`n"
        MakeStamp $hx (PathOf $msi) 'package'
        $m = @(PathOf $msi)
        Expect "$hn fresh package passes" 0 (RunAssert $hx $m)
        $msiBytes = [IO.File]::ReadAllBytes((PathOf $msi)); $msiTime = (Get-Item (PathOf $msi)).LastWriteTime
        [IO.File]::WriteAllBytes((PathOf $msi), [Text.Encoding]::ASCII.GetBytes("old`n"))
        (Get-Item (PathOf $msi)).LastWriteTime = $msiTime.AddDays(-9)
        Expect "$hn an old msi copied over the stamped one is refused" 1 (RunAssert $hx $m)
        [IO.File]::WriteAllBytes((PathOf $msi), $msiBytes)
        Expect "$hn the stamped msi back is fresh again" 0 (RunAssert $hx $m)
        Put 'installer/Test-x.ps1' "# test changed`n"
        Put 'installer/GUIDS.md' "notes changed`n"
        Expect "$hn test script / notes in installer\ are not packed, stay fresh" 0 (RunAssert $hx $m)
        Put 'installer/7-ZSTar.wxs' "<Wix changed/>`n"
        Expect "$hn changed .wxs stales the package" 1 (RunAssert $hx $m)
        Expect "$hn ... but not the binaries" 0 (RunAssert $hx $a)
        Put 'installer/7-ZSTar.wxs' "<Wix/>`n"
        Put 'CHANGELOG.md' "changed`n"
        Expect "$hn changed packed document stales the package" 1 (RunAssert $hx $m)
        Put 'CHANGELOG.md' "CHANGELOG.md`n"
        Put 'CPP/b.cpp' "int b = 3;`n"
        Expect "$hn changed source stales the package too" 1 (RunAssert $hx $m)
        Put 'CPP/b.cpp' "int b;`n"
        Expect "$hn package fresh again after revert" 0 (RunAssert $hx $m)

        # clean up for the next host: tests start from the committed tree
        GitC @('checkout', '--', '.')
        Put 'installer/Test-x.ps1' "# test`n"
        Put 'installer/GUIDS.md' "notes`n"
    }

    # --- no git: refuse, do not guess -------------------------------------------
    # Outside $Work on purpose: inside it, git would find the scratch repo above.
    $bare = Join-Path ([IO.Path]::GetTempPath()) ('7zstar-nogit-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Force (Join-Path $bare 'build') | Out-Null
    Copy-Item (PathOf 'build\SourceStamp.ps1') (Join-Path $bare 'build\SourceStamp.ps1')
    Copy-Item (PathOf 'build\Assert-Fresh.ps1') (Join-Path $bare 'build\Assert-Fresh.ps1')
    Set-Content (Join-Path $bare 'x.exe') 'x'
    Set-Content (Join-Path $bare '.srcstamp') '{"kind":"binary","fingerprint":"abc","head":"h","created":"2026-01-01T00:00:00"}'
    $hx0 = @($hosts.Values)[0]
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        $script:LastOutput = (& $hx0 -NoProfile -ExecutionPolicy Bypass -File (Join-Path $bare 'build\Assert-Fresh.ps1') -Path (Join-Path $bare 'x.exe') 2>&1 | Out-String)
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prev }
    Expect 'outside a git work tree the check refuses' 1 $code
} finally {
    Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue
    if ($bare) { Remove-Item -LiteralPath $bare -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host ''
Write-Host ("{0} passed, {1} failed" -f $script:Pass, $script:Fail)
if ($script:Fail -gt 0) { exit 1 }
exit 0

# 7-ZSTar build-artifact freshness stamps. Dot-source this file; it only
# defines functions.
#
#   . (Join-Path $RepoRoot 'build\SourceStamp.ps1')
#
# Why this exists: a build artifact that is older than the source it should
# reflect looks exactly like a good one - the build log is green, the tests
# are green, the file is there. This repo has shipped that way more than once
# (nmake does not track .rc includes or PCH dependencies; a packaging run
# picked up an old dist). So the producer records WHICH SOURCE it was made
# from, and every consumer compares that record with the source as it is now,
# and refuses to go on when they differ.
#
# The record is a content fingerprint of the work tree, not a commit hash: it
# covers uncommitted edits and new untracked files (the usual "edited, did not
# rebuild" case), skips everything .gitignore skips, and ignores files that do
# not feed the artifact (a documentation change does not make a binary stale).
#
#   kind 'binary'   C, CPP, Asm. Written next to each built target:
#                   <target>\<platform>\.srcstamp          (build\Build.ps1)
#   kind 'package'  the binary inputs plus what installer\Build-Package.ps1
#                   packs around them. Written beside each .msi / .zip as
#                   <file>.srcstamp                       (installer\Build-Package.ps1)
#
# Limit, stated once: a stamp proves the build driver ran on this source, not
# that nmake rebuilt everything it should have. For edits it is known to miss
# (headers pulled in by .rc files, precompiled headers) use Build.ps1 -Clean.
#
# Compatible with Windows PowerShell 5.1 and PowerShell 7. Keep it ASCII.

$script:SrcStampDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$script:SrcStampRepoRoot = Split-Path -Parent $script:SrcStampDir
$script:SrcStampFileName = '.srcstamp'

# Paths are repo-relative with forward slashes (the form `git ls-files` prints).
# An entry matches a file when it equals the path or is a directory prefix.
# Exclude entries are -like patterns over the whole path ('*' also crosses '/').
$script:SrcStampKinds = @{
    binary  = @{
        Include = @('C', 'CPP', 'Asm')
        Exclude = @()
    }
    package = @{
        Include = @('C', 'CPP', 'Asm', 'installer', 'Lang', 'Help',
                    'LICENSE', 'COPYING', 'LICENSE-EXCEPTIONS.md', 'LICENSE-7-Zip.txt',
                    'NOTICE', 'README.md', 'CHANGELOG.md')
        # Test scripts and notes in installer\ are not packed.
        Exclude = @('installer/Test-*.ps1', 'installer/GUIDS.md')
    }
}

function Invoke-SrcStampGit {
    param([string]$RepoRoot, [string[]]$GitArgs)
    # Windows PowerShell 5.1 turns native stderr output into a terminating
    # error under $ErrorActionPreference = 'Stop'; relax it for the call.
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & git -C $RepoRoot -c core.quotePath=false @GitArgs 2>&1
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prev
    }
    return [pscustomobject]@{ Code = $code; Out = @($out | ForEach-Object { "$_" }) }
}

function Get-SourceFingerprint {
    <#
    .SYNOPSIS
        Content fingerprint of the work tree for one stamp kind.
    .DESCRIPTION
        Stages the work tree into a throw-away copy of the index (the real
        index is never touched), lists it and hashes the (mode, blob, path)
        lines that belong to the kind. Returns an object with Fingerprint,
        Files and Head. Throws when git is missing or RepoRoot is not a work
        tree - callers that can live without a stamp catch that.

        Not cached: a long-lived process that checks, then edits source, then
        checks again must see the edit. (Assert-ArtifactFresh caches within
        one call only.) Side effect worth knowing: `git add -A` writes a blob
        object for every edited or untracked file into the real object
        database. They are unreachable and `git gc` collects them; the index
        and the work tree are not touched.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('binary', 'package')][string]$Kind,
        [string]$RepoRoot = $script:SrcStampRepoRoot
    )

    if (-not (Get-Command git -CommandType Application -ErrorAction SilentlyContinue)) {
        throw 'git was not found on PATH; the source fingerprint needs it.'
    }
    $gd = Invoke-SrcStampGit $RepoRoot @('rev-parse', '--absolute-git-dir')
    if ($gd.Code -ne 0 -or -not $gd.Out) {
        throw "$RepoRoot is not a git work tree; the source fingerprint needs one. ($($gd.Out -join ' '))"
    }
    $gitDir = $gd.Out[0]
    $head = Invoke-SrcStampGit $RepoRoot @('rev-parse', 'HEAD')
    $headId = if ($head.Code -eq 0 -and $head.Out) { $head.Out[0] } else { 'unborn' }

    $realIndex = Join-Path $gitDir 'index'
    $tmpIndex = Join-Path ([IO.Path]::GetTempPath()) ('7zstar-fp-' + [guid]::NewGuid().ToString('N') + '.idx')
    $prevIdx = $env:GIT_INDEX_FILE
    try {
        # Seeding from the real index lets git skip re-hashing every file whose
        # stat data is unchanged; only edited or new files are read.
        if (Test-Path -LiteralPath $realIndex) { Copy-Item -LiteralPath $realIndex -Destination $tmpIndex -Force }
        $env:GIT_INDEX_FILE = $tmpIndex
        $add = Invoke-SrcStampGit $RepoRoot @('add', '-A')
        if ($add.Code -ne 0) { throw "git add -A (temporary index) failed: $($add.Out -join ' ')" }
        $ls = Invoke-SrcStampGit $RepoRoot @('ls-files', '-s')
        if ($ls.Code -ne 0) { throw "git ls-files failed: $($ls.Out -join ' ')" }
    } finally {
        if ($null -eq $prevIdx) { Remove-Item Env:\GIT_INDEX_FILE -ErrorAction SilentlyContinue }
        else { $env:GIT_INDEX_FILE = $prevIdx }
        Remove-Item -LiteralPath $tmpIndex -Force -ErrorAction SilentlyContinue
    }

    $set = $script:SrcStampKinds[$Kind]
    $kept = New-Object Collections.Generic.List[string]
    foreach ($line in $ls.Out) {
        # "<mode> <blob> <stage>\t<path>"
        $tab = $line.IndexOf("`t")
        if ($tab -lt 0) { continue }
        $path = $line.Substring($tab + 1)
        $hit = $false
        foreach ($inc in $set.Include) {
            if ($path -eq $inc -or $path.StartsWith($inc + '/')) { $hit = $true; break }
        }
        if (-not $hit) { continue }
        foreach ($exc in $set.Exclude) {
            if ($path -like $exc) { $hit = $false; break }
        }
        if ($hit) { $kept.Add($line) }
    }
    if ($kept.Count -eq 0) { throw "No files matched stamp kind '$Kind' under $RepoRoot." }

    $bytes = [Text.Encoding]::UTF8.GetBytes(($kept -join "`n"))
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $hash = ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join '' }
    finally { $sha.Dispose() }

    return [pscustomobject]@{ Kind = $Kind; Fingerprint = $hash; Files = $kept.Count; Head = $headId }
}

function Get-SourceStampPath {
    # .msi / .zip: a sidecar next to the file. Anything else (an .exe or .dll
    # from the build tree): the .srcstamp in the same directory.
    param([Parameter(Mandatory)][string]$Artifact)
    $ext = [IO.Path]::GetExtension($Artifact).ToLowerInvariant()
    if ($ext -eq '.msi' -or $ext -eq '.zip') { return $Artifact + $script:SrcStampFileName }
    return Join-Path (Split-Path -Parent $Artifact) $script:SrcStampFileName
}

function Get-ArtifactDigest {
    param([Parameter(Mandatory)][string]$Path)
    [ordered]@{
        length = (Get-Item -LiteralPath $Path).Length
        sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

function Write-SourceStamp {
    <#
    .SYNOPSIS
        Record which source the given artifact files were made from.
    .DESCRIPTION
        Besides the fingerprint, the stamp lists each artifact by file name
        with its length and SHA256. A directory stamp (one per build target)
        lists every file the target produced; a sidecar lists its one file.
        The check compares those, so an old file copied back over a stamped one
        is caught even when the copy kept its old modification time.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$StampPath,
        [Parameter(Mandatory)]$Fingerprint,
        [string[]]$ArtifactFiles = @()
    )
    $arts = [ordered]@{}
    foreach ($f in $ArtifactFiles) { $arts[(Split-Path -Leaf $f)] = Get-ArtifactDigest $f }
    $o = [ordered]@{
        kind        = $Fingerprint.Kind
        fingerprint = $Fingerprint.Fingerprint
        files       = $Fingerprint.Files
        head        = $Fingerprint.Head
        created     = (Get-Date).ToString('s')
        artifacts   = $arts
    }
    $json = $o | ConvertTo-Json -Compress -Depth 5
    [IO.File]::WriteAllText($StampPath, $json, (New-Object Text.UTF8Encoding $false))
}

function Remove-SourceStamp {
    param([Parameter(Mandatory)][string]$StampPath)
    Remove-Item -LiteralPath $StampPath -Force -ErrorAction SilentlyContinue
}

function Assert-ArtifactFresh {
    <#
    .SYNOPSIS
        Throw unless every artifact was made from the source as it is now.
    .DESCRIPTION
        For each artifact: its stamp must exist, parse, carry the fingerprint
        the work tree has now for the stamp's kind, and list the artifact with
        the length and SHA256 it has now (so a file swapped after stamping is
        caught whatever its modification time). -Skip turns all of that off
        for a deliberate case (an unpacked release, a downloaded .msi): it
        prints a warning and appends a line to build\logs\freshness-skips.log.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$Path,
        [switch]$Skip,
        [string]$Caller = '',
        [string]$RepoRoot = $script:SrcStampRepoRoot
    )

    if ($Skip) {
        Write-Warning ("Freshness check SKIPPED for: " + (($Path | ForEach-Object { Split-Path -Leaf $_ }) -join ', ') +
                       ". Nothing proves these match the current source.")
        try {
            $logDir = Join-Path $RepoRoot 'build\logs'
            New-Item -ItemType Directory -Force $logDir | Out-Null
            $stamp = (Get-Date).ToString('s')
            $lines = $Path | ForEach-Object { "$stamp`t$env:USERNAME`t$Caller`t$_" }
            Add-Content -LiteralPath (Join-Path $logDir 'freshness-skips.log') -Value $lines -Encoding UTF8
        } catch {
            Write-Warning "Could not write build\logs\freshness-skips.log: $($_.Exception.Message)"
        }
        return
    }

    $problems = New-Object Collections.Generic.List[string]
    $okKinds = @{}
    $nowByKind = @{}   # one fingerprint per kind per call, not per artifact
    foreach ($artifact in $Path) {
        $leaf = Split-Path -Leaf $artifact
        if (-not (Test-Path -LiteralPath $artifact)) { $problems.Add("${leaf}: file not found ($artifact)"); continue }
        $stampPath = Get-SourceStampPath $artifact
        if (-not (Test-Path -LiteralPath $stampPath)) {
            $problems.Add("${leaf}: no source stamp ($stampPath). It predates the stamp, was built without git, or did not come from this tree's build.")
            continue
        }
        try {
            $rec = [IO.File]::ReadAllText($stampPath) | ConvertFrom-Json
            if (-not $rec.kind -or -not $rec.fingerprint) { throw 'missing kind/fingerprint' }
            if ($rec.kind -notin 'binary', 'package') { throw "unknown kind '$($rec.kind)'" }
        } catch {
            $problems.Add("${leaf}: unreadable stamp $stampPath ($($_.Exception.Message))")
            continue
        }
        try {
            if (-not $nowByKind.ContainsKey($rec.kind)) {
                $nowByKind[$rec.kind] = Get-SourceFingerprint -Kind $rec.kind -RepoRoot $RepoRoot
            }
            $now = $nowByKind[$rec.kind]
        } catch {
            $problems.Add("${leaf}: cannot compute the current source fingerprint ($($_.Exception.Message))")
            continue
        }
        if ($now.Fingerprint -ne $rec.fingerprint) {
            $problems.Add("${leaf}: made from different source (stamp $($rec.fingerprint.Substring(0, 12)) at HEAD $("$($rec.head)".Substring(0, [Math]::Min(9, "$($rec.head)".Length))) on $($rec.created); " +
                          "source now $($now.Fingerprint.Substring(0, 12)) at HEAD $($now.Head.Substring(0, [Math]::Min(9, $now.Head.Length)))).")
            continue
        }
        # The source matches; is this file the one that was stamped?
        $entry = $null
        if ($rec.artifacts) { $entry = $rec.artifacts.PSObject.Properties[$leaf] }
        if (-not $entry) {
            $problems.Add("${leaf}: not listed in its stamp ($stampPath) - it was not produced by the build that was stamped.")
            continue
        }
        $have = Get-ArtifactDigest $artifact
        if ([int64]$entry.Value.length -ne [int64]$have.length -or $entry.Value.sha256 -ne $have.sha256) {
            $problems.Add("${leaf}: contents differ from what was stamped (stamped $($entry.Value.length) bytes, now $($have.length)); the file was replaced after the build.")
            continue
        }
        $okKinds[$rec.kind] = $now.Fingerprint
    }

    if ($problems.Count -gt 0) {
        throw ("Stale or unverifiable build artifact" + $(if ($problems.Count -gt 1) { 's' }) +
               " (rebuild with build\Build.ps1 / installer\Build-Package.ps1 - every target this script reads, not just some of them after a -Targets build; or pass -SkipFreshnessCheck on purpose):`n  " +
               ($problems -join "`n  "))
    }
    $summary = ($okKinds.GetEnumerator() | ForEach-Object { "$($_.Key) $($_.Value.Substring(0, 12))" }) -join ', '
    Write-Host ("  freshness OK: {0} artifact(s) match the current source ({1})" -f $Path.Count, $summary)
}

# Check that build artifacts were made from the source tree as it is now.
#
#   pwsh build\Assert-Fresh.ps1 installer\dist\7-ZSTar-26.05.1-x64.msi
#   pwsh build\Assert-Fresh.ps1 CPP\7zip\UI\Console\x64\7z.exe CPP\7zip\Bundles\Format7zF\x64\7z.dll
#
# Exit code 0: every artifact matches the current source. Exit code 1: at
# least one is stale, unstamped or unreadable (the reasons are printed). Exit
# code 2: the check itself failed - a defect, not a verdict; treat it as "do
# not proceed" as well, and report it. Meant
# for scripts that take an artifact from somewhere this repo cannot see - VM
# acceptance runs above all - and want one line to gate on:
#
#   pwsh build\Assert-Fresh.ps1 $msi; if ($LASTEXITCODE -ne 0) { throw 'stale msi' }
#
# -SkipFreshnessCheck passes anything through, with a warning and a line in
# build\logs\freshness-skips.log. Library and the rules: build\SourceStamp.ps1.

[CmdletBinding()]
param(
    # ValueFromRemainingArguments: `-File Assert-Fresh.ps1 -Path a b` delivers
    # both (a comma list would arrive as one string under -File).
    [Parameter(Mandatory, Position = 0, ValueFromRemainingArguments)]
    [string[]]$Path,

    [switch]$SkipFreshnessCheck
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'SourceStamp.ps1')

$full = @($Path | ForEach-Object {
    $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($_)
})
try {
    Assert-ArtifactFresh -Path $full -Skip:$SkipFreshnessCheck -Caller 'Assert-Fresh.ps1'
} catch {
    if ($_.FullyQualifiedErrorId -like 'SourceStampStale*') {
        Write-Host "STALE: $($_.Exception.Message)"
        exit 1
    }
    Write-Host "CHECK FAILED (not a freshness verdict): $($_.Exception.Message)"
    exit 2
}
exit 0

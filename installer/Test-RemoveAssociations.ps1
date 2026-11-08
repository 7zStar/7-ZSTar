<#
.SYNOPSIS
    Check that Setup-ShellIntegration.ps1 -RemoveAssociations removes exactly
    this product's file associations and nothing else.

.DESCRIPTION
    Runs the real script - through its -ClassesRoot hook - against a scratch
    key under HKCU, because the live version deletes every 7-ZSTar.* ProgID it
    finds and cannot be exercised against the real hive without destroying the
    user's own associations.

    Both halves matter. Removing too little leaves a file type pointing at a
    ProgID whose icon and command are a deleted executable, which Explorer
    draws as a blank icon - the bug this cleanup exists to fix, and one an
    earlier implementation shipped: Remove-ItemProperty cannot delete a key's
    unnamed (default) value, and fails at it silently. Removing too much takes
    away an association the user has since given to another program.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File installer\Test-RemoveAssociations.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# $PSScriptRoot is not populated during parameter binding on 5.1, so this is
# resolved in the body.
$selfDir = if ($PSCommandPath) { Split-Path -Parent $PSCommandPath }
           elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
           else { (Get-Location).Path }
$script = Join-Path $selfDir 'Setup-ShellIntegration.ps1'
if (-not (Test-Path -LiteralPath $script)) { throw "not found: $script" }

$root   = 'Software\7-ZSTar-assoc-test'
$rootPs = "Registry::HKEY_CURRENT_USER\$root"

function New-Key($rel, $default) {
    $p = "$rootPs\$rel"
    New-Item -Path $p -Force | Out-Null
    if ($null -ne $default) { Set-ItemProperty -LiteralPath $p -Name '(default)' -Value $default }
    return $p
}

Remove-Item -LiteralPath $rootPs -Recurse -Force -ErrorAction SilentlyContinue
New-Item -Path $rootPs -Force | Out-Null

# Stand-ins for this install and for a portable copy elsewhere, each with a
# 7zFM.exe: which of the two a ProgID's open command names decides its fate.
$tmpBase = Join-Path $env:TEMP '7-ZSTar-assoc-test'
$inst = Join-Path $tmpBase 'install'
$port = Join-Path $tmpBase 'portable'
# Shares $inst's name as a prefix: outside the install all the same.
$adj  = Join-Path $tmpBase 'install2'
Remove-Item -LiteralPath $tmpBase -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $inst, $port, $adj | Out-Null
foreach ($f in (Join-Path $inst '7zFM.exe'), (Join-Path $port '7zFM.exe'),
               (Join-Path $adj '7zFM.exe'), (Join-Path $port 'other.exe')) {
    Set-Content -LiteralPath $f -Value ''
}
function New-ProgId($name, $exe) {
    New-Key $name '7-ZSTar archive' | Out-Null
    New-Key "$name\shell\open\command" "`"$exe`" `"%1`"" | Out-Null
}

# .keep7z  ours outright                  -> must go, key and all
# .other   someone else's, but we are in
#          its OpenWithProgids            -> only our value may go
# .mixed   nothing to do with us          -> must not be touched
New-Key '.keep7z' '7-ZSTar.keep7z' | Out-Null
$other = New-Key '.other' 'OtherApp.other'
New-Item -Path "$other\OpenWithProgids" -Force | Out-Null
# Empty REG_SZ, which is the shape Explorer writes: OpenWithProgids carries
# meaning in its value *names*, and the values themselves are empty.
Set-ItemProperty -LiteralPath "$other\OpenWithProgids" -Name '7-ZSTar.other' -Value '' -Type String
Set-ItemProperty -LiteralPath "$other\OpenWithProgids" -Name 'OtherApp.other' -Value '' -Type String
New-Key '.mixed' 'OtherApp.mixed' | Out-Null
New-Key '7-ZSTar.keep7z' '7-ZSTar archive' | Out-Null
New-Key '7-ZSTar.other'  '7-ZSTar archive' | Out-Null
New-Key 'OtherApp.other' 'Other app file' | Out-Null
New-Key 'OtherApp.mixed' 'Other app file' | Out-Null
# .here    ours, command into this install -> must go
# .port    a portable copy's, still there  -> must stay, with its file type,
#          and as a candidate in .other's OpenWithProgids
# .adj     the same, in install2\          -> must stay (prefix is not parent)
# .gone    command names a missing program -> must go (dangling)
# .notfm   names an existing program that
#          is not 7zFM.exe                 -> must go
New-Key '.here' '7-ZSTar.here' | Out-Null
New-Key '.port' '7-ZSTar.port' | Out-Null
New-Key '.adj' '7-ZSTar.adj' | Out-Null
New-Key '.gone' '7-ZSTar.gone' | Out-Null
New-Key '.notfm' '7-ZSTar.notfm' | Out-Null
New-ProgId '7-ZSTar.here' (Join-Path $inst '7zFM.exe')
New-ProgId '7-ZSTar.port' (Join-Path $port '7zFM.exe')
New-ProgId '7-ZSTar.adj' (Join-Path $adj '7zFM.exe')
New-ProgId '7-ZSTar.gone' (Join-Path $tmpBase 'missing\7zFM.exe')
New-ProgId '7-ZSTar.notfm' (Join-Path $port 'other.exe')
Set-ItemProperty -LiteralPath "$other\OpenWithProgids" -Name '7-ZSTar.port' -Value '' -Type String

Write-Host '--- before'
Get-ChildItem $rootPs | ForEach-Object {
    Write-Host ("    {0,-16} default='{1}'" -f $_.PSChildName,
                (Get-ItemProperty -LiteralPath $_.PSPath).'(default)')
}

Write-Host '--- running Setup-ShellIntegration.ps1 -RemoveAssociations against the scratch root'
& powershell.exe -NoProfile -ExecutionPolicy Bypass `
    -Command "& '$script' -RemoveAssociations -ClassesRoot '$root' -InstallFolder '$inst'" |
    ForEach-Object { Write-Host "    $_" }

Write-Host '--- after'
$after = @{}
Get-ChildItem $rootPs | ForEach-Object {
    $d = (Get-ItemProperty -LiteralPath $_.PSPath).'(default)'
    $after[$_.PSChildName] = $d
    Write-Host ("    {0,-16} default='{1}'" -f $_.PSChildName, $d)
}
$owp = Get-ItemProperty -LiteralPath "$rootPs\.other\OpenWithProgids" -ErrorAction SilentlyContinue
$owpNames = if ($owp) { @($owp.PSObject.Properties |
                          Where-Object { $_.Name -notlike 'PS*' } |
                          ForEach-Object { $_.Name }) } else { @() }
Write-Host "    .other\OpenWithProgids = $($owpNames -join ', ')"

$checks = [ordered]@{
    '.keep7z key gone entirely'            = (-not $after.ContainsKey('.keep7z'))
    '.other kept, default untouched'       = ($after['.other'] -eq 'OtherApp.other')
    ".other's OpenWithProgids lost ours"   = ($owpNames -notcontains '7-ZSTar.other')
    ".other's OpenWithProgids kept theirs" = ($owpNames -contains 'OtherApp.other')
    '.mixed untouched'                     = ($after['.mixed'] -eq 'OtherApp.mixed')
    '7-ZSTar.keep7z ProgID gone'           = (-not $after.ContainsKey('7-ZSTar.keep7z'))
    '7-ZSTar.other ProgID gone'            = (-not $after.ContainsKey('7-ZSTar.other'))
    'OtherApp.other ProgID kept'           = $after.ContainsKey('OtherApp.other')
    'OtherApp.mixed ProgID kept'           = $after.ContainsKey('OtherApp.mixed')
    '7-ZSTar.here ProgID gone (this install)'      = (-not $after.ContainsKey('7-ZSTar.here'))
    '.here key gone entirely'                      = (-not $after.ContainsKey('.here'))
    '7-ZSTar.port ProgID kept (other copy exists)' = $after.ContainsKey('7-ZSTar.port')
    '.port default kept'                           = ($after['.port'] -eq '7-ZSTar.port')
    ".other's OpenWithProgids kept the other copy's" = ($owpNames -contains '7-ZSTar.port')
    '7-ZSTar.adj ProgID kept (install2 is not install)' = $after.ContainsKey('7-ZSTar.adj')
    '.adj default kept'                            = ($after['.adj'] -eq '7-ZSTar.adj')
    '7-ZSTar.gone ProgID gone (program missing)'   = (-not $after.ContainsKey('7-ZSTar.gone'))
    '.gone key gone entirely'                      = (-not $after.ContainsKey('.gone'))
    '7-ZSTar.notfm ProgID gone (not 7zFM.exe)'     = (-not $after.ContainsKey('7-ZSTar.notfm'))
    '.notfm key gone entirely'                     = (-not $after.ContainsKey('.notfm'))
    # The one an earlier implementation failed: ProgIDs deleted, file types
    # left naming them.
    'no dangling 7-ZSTar.* default left'   = (@($after.Values | Where-Object { $_ -like '7-ZSTar.*' -and -not $after.ContainsKey($_) }).Count -eq 0)
}

Write-Host '--- verdict'
$fail = 0
foreach ($k in $checks.Keys) {
    if (-not $checks[$k]) { $fail++ }
    Write-Host ("  [{0}] {1}" -f $(if ($checks[$k]) { 'PASS' } else { 'FAIL' }), $k)
}
Write-Host ("  {0}/{1} passed" -f ($checks.Count - $fail), $checks.Count)

Remove-Item -LiteralPath $rootPs -Recurse -Force
Remove-Item -LiteralPath $tmpBase -Recurse -Force
exit $fail

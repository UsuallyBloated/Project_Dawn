# Runs every headless check in tools/ (tools/check_*.gd) and prints one line
# per check plus a summary. Exit code 1 if any check failed, so it can gate an
# export. The lockstep checks compare this repo's data with the server repo's
# (by default the checkout at F:\Projects\server); a check that cannot find
# its server file exits 2 and shows here as failed.
#
# Usage, from the client repo root:
#   .\tools\check_all.ps1
#   .\tools\check_all.ps1 -Verbose     # also print each check's full output

[CmdletBinding()]
param(
    # The console build: the plain Godot .exe is a GUI program, which
    # PowerShell neither waits for nor reads an exit code from.
    [string]$Godot = "F:\GODOT Engine\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64_console.exe"
)

$root = Split-Path -Parent $PSScriptRoot
$checks = Get-ChildItem -Path (Join-Path $root "tools") -Filter "check_*.gd" | Sort-Object Name
if ($checks.Count -eq 0) {
    Write-Host "No checks found in tools\."
    exit 1
}

$failed = @()
foreach ($check in $checks) {
    $output = & $Godot --headless --path $root -s ("tools/" + $check.Name) 2>&1
    $code = $LASTEXITCODE
    if ($code -eq 0) {
        Write-Host ("PASS  {0}" -f $check.Name)
    } else {
        Write-Host ("FAIL  {0}  (exit {1})" -f $check.Name, $code)
        $failed += $check.Name
    }
    if ($code -ne 0 -or $VerbosePreference -eq "Continue") {
        $output | Where-Object { $_ -and ($_ -notmatch "^Godot Engine") } | ForEach-Object { Write-Host ("      " + $_) }
    }
}

Write-Host ""
if ($failed.Count -gt 0) {
    Write-Host ("{0} of {1} checks failed: {2}" -f $failed.Count, $checks.Count, ($failed -join ", "))
    exit 1
}
Write-Host ("All {0} checks passed." -f $checks.Count)
exit 0

# Runs every headless check in tools/ (tools/check_*.gd) and prints one line
# per check plus a summary. Exit code 1 if any check failed, so it can gate an
# export. The lockstep checks compare this repo's data with the server repo's;
# a check that cannot find its server file exits 2 and shows here as failed.
#
# Usage, from the client repo root:
#   .\tools\check_all.ps1
#   .\tools\check_all.ps1 -Verbose                               # also print each check's full output
#   .\tools\check_all.ps1 -ServerRoot F:\Projects\server-height   # a feature branch's server worktree
#
# Every lockstep check reads its server file from a default inside the deploy
# checkout (F:\Projects\server) unless it is given a path as its one user
# argument, so on a feature branch pair the two worktrees with -ServerRoot, or
# the checks compare a feature branch's client against the deploy branch's
# server and report drift that is not there (or miss drift that is).

[CmdletBinding()]
param(
    # The console build: the plain Godot .exe is a GUI program, which
    # PowerShell neither waits for nor reads an exit code from.
    [string]$Godot = "F:\GODOT Engine\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64_console.exe",
    # The server checkout the lockstep checks compare against.
    [string]$ServerRoot = "F:\Projects\server"
)

$root = Split-Path -Parent $PSScriptRoot
$checks = Get-ChildItem -Path (Join-Path $root "tools") -Filter "check_*.gd" | Sort-Object Name
if ($checks.Count -eq 0) {
    Write-Host "No checks found in tools\."
    exit 1
}

# What each lockstep check wants as its server-path argument, relative to the
# server repo root (an empty string is the root itself). A check not listed
# here takes no argument. Keep this in step with each check's DEFAULT_ const.
$serverData = "crates/projectdawn-server/data"
$serverSrc = "crates/projectdawn-server/src"
$serverPaths = @{
    "check_active_skill_lockstep.gd" = "$serverData/active_skills.toml"
    "check_character_lockstep.gd"    = "$serverSrc/char_data.rs"
    "check_constant_lockstep.gd"     = $serverSrc
    "check_discipline_lockstep.gd"   = "$serverSrc/world/skills.rs"
    "check_faction_lockstep.gd"      = "$serverData/factions.toml"
    "check_invariants.gd"            = ""
    "check_item_lockstep.gd"         = "$serverData/items.toml"
    "check_skill_table_lockstep.gd"  = "$serverSrc/world/skills.rs"
    "check_spell_lockstep.gd"        = "$serverData/spells.toml"
    "check_terrain_lockstep.gd"      = $serverData
    "check_vendor_lockstep.gd"       = "$serverData/npcs.toml"
}

$serverRootSlashed = ($ServerRoot -replace '\\', '/').TrimEnd('/')
if (-not (Test-Path (Join-Path $ServerRoot "Cargo.toml"))) {
    Write-Host ("Server repo not found at {0} (no Cargo.toml); pass -ServerRoot." -f $ServerRoot)
    exit 1
}
Write-Host ("Lockstep checks compare against {0}" -f $serverRootSlashed)

$failed = @()
foreach ($check in $checks) {
    $godotArgs = @("--headless", "--path", $root, "-s", ("tools/" + $check.Name))
    if ($serverPaths.ContainsKey($check.Name)) {
        $rel = $serverPaths[$check.Name]
        $target = if ($rel -eq "") { $serverRootSlashed } else { "$serverRootSlashed/$rel" }
        $godotArgs += @("--", $target)
    }
    $output = & $Godot @godotArgs 2>&1
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

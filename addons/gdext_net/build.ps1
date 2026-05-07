# Build the gdext-net GDExtension and copy the .dll into this directory.
#
# Run from anywhere (path-agnostic). On first build the gdext crate compiles
# from scratch and takes ~3 minutes; later rebuilds are ~30 seconds.

$ErrorActionPreference = "Stop"

$serverDir = "F:/Projects/server"
$crateName = "gdext-net"
$libName   = "gdext_net.dll"
$destDir   = $PSScriptRoot
$built     = Join-Path $serverDir "target/release/$libName"
$dest      = Join-Path $destDir $libName

if (-not (Test-Path (Join-Path $serverDir "Cargo.toml"))) {
    throw "Server repo not found at $serverDir — adjust `$serverDir in build.ps1."
}

Write-Host "Building $crateName (release)..." -ForegroundColor Cyan
Push-Location $serverDir
try {
    cargo build -p $crateName --release
    if ($LASTEXITCODE -ne 0) {
        throw "cargo build failed (exit $LASTEXITCODE)"
    }
} finally {
    Pop-Location
}

if (-not (Test-Path $built)) {
    throw "Expected build artifact not found: $built"
}

Copy-Item -Path $built -Destination $dest -Force
$size = (Get-Item $dest).Length
Write-Host "Copied $libName ($([math]::Round($size / 1MB, 2)) MB) -> $dest" -ForegroundColor Green
Write-Host "Reload the Godot editor (Project > Reload Current Project) to pick up the new build." -ForegroundColor Yellow

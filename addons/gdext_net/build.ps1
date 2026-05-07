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

Write-Host "Building $crateName (release, +crt-static)..." -ForegroundColor Cyan
# Static CRT linkage so the .dll has no run-time dependency on
# VCRUNTIME140.dll / MSVCP140.dll. Godot's exported-game DLL search path
# is restricted enough that dynamic-CRT .dlls fail to load with "Error 126:
# module not found" on systems that don't happen to have the runtime in
# a Godot-visible directory. Bigger .dll, but reliable.
Push-Location $serverDir
try {
    $env:RUSTFLAGS = "-C target-feature=+crt-static"
    cargo build -p $crateName --release
    $exit = $LASTEXITCODE
} finally {
    Remove-Item Env:RUSTFLAGS -ErrorAction SilentlyContinue
    Pop-Location
}
if ($exit -ne 0) {
    throw "cargo build failed (exit $exit)"
}

if (-not (Test-Path $built)) {
    throw "Expected build artifact not found: $built"
}

Copy-Item -Path $built -Destination $dest -Force
$size = (Get-Item $dest).Length
Write-Host "Copied $libName ($([math]::Round($size / 1MB, 2)) MB) -> $dest" -ForegroundColor Green
Write-Host "Reload the Godot editor (Project > Reload Current Project) to pick up the new build." -ForegroundColor Yellow

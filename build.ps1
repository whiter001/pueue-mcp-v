# Simple build helper for Windows (PowerShell)
# Usage:
#   .\build.ps1        # run tests and compile binary
#   .\build.ps1 clean  # remove generated binary

param (
    [string]$command = "build"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

if ($command -eq "clean") {
    if (Test-Path "$Root\pueue-mcp.exe") {
        Remove-Item "$Root\pueue-mcp.exe"
        Write-Host "cleaned"
    }
} else {
    Write-Host "running core tests..."
    v test "$Root\core"
    if ($LASTEXITCODE -ne 0) { exit 1 }

    Write-Host "building binary..."
    v -o "$Root\pueue-mcp.exe" "$Root\main.v"
    Write-Host "built $Root\pueue-mcp.exe"
}

# Simple formatting helper for the pueue-mcp-v project
# Run this script to format all source files in the repository.

$ROOT = Split-Path -Parent $MyInvocation.MyCommand.Path

# Format V files
Write-Host "Formatting V files..."
Get-ChildItem -Path $ROOT -Filter "*.v" -Recurse | ForEach-Object { v fmt $_.FullName }

Write-Host "formatted V files"

# Format markdown files with oxfmt
Write-Host "Formatting markdown files with oxfmt..."
npx --yes oxfmt@latest "$ROOT/**/*.md" 2>$null || $true

Write-Host "formatted markdown"

# Format TypeScript files with oxfmt
Write-Host "Formatting TypeScript files with oxfmt..."
npx --yes oxfmt@latest "$ROOT/**/*.ts" 2>$null || $true

Write-Host "formatted TypeScript files"

# Lint TypeScript files with oxlint
Write-Host "Linting TypeScript files with oxlint..."
npx --yes oxlint@latest "$ROOT/**/*.ts" --fix 2>$null || $true

Write-Host "linted TypeScript files"

# Type check TypeScript files with tsc
Write-Host "Type checking TypeScript files with tsc..."
npx --yes tsc --noEmit --project "$ROOT/tsconfig.json" 2>$null || $true

Write-Host "type checked TypeScript files"

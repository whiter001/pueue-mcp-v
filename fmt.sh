#!/usr/bin/env bash
set -euo pipefail

# Simple formatting helper for the pueue-mcp-v project
# Run this script to format all V source files in the repository.

ROOT=$(dirname "$0")

find "$ROOT" -name '*.v' -print0 | xargs -0 v fmt

echo "formatted V files"

# format markdown with oxfmt (requires node/npm)
echo "formatting markdown files with oxfmt..."
npx --yes oxfmt@latest "$ROOT"/**/*.md || true

echo "formatted markdown"

# format TypeScript files with oxfmt
echo "formatting TypeScript files with oxfmt..."
npx --yes oxfmt@latest "$ROOT"/**/*.ts || true

echo "formatted TypeScript files"

# lint TypeScript files with oxlint (optional)
echo "linting TypeScript files with oxlint..."
npx --yes oxlint@latest "$ROOT"/**/*.ts --fix || true

echo "linted TypeScript files"

# Type check TypeScript files with tsc
echo "type checking TypeScript files with tsc..."
npx --yes tsc --noEmit --project "$ROOT/tsconfig.json" || true

echo "type checked TypeScript files"
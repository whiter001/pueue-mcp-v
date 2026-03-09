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
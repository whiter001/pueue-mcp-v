#!/usr/bin/env bash
set -euo pipefail

# Simple build helper for the pueue-mcp-v project
#
# Usage:
#   ./build.sh        # run tests and compile binary
#   ./build.sh clean  # remove generated binary

ROOT=$(dirname "$0")

case ${1:-} in
    clean)
        rm -f "$ROOT/pueue-mcp"
        echo "cleaned"
        ;;
    *)
        echo "running core tests..."
        v test "$ROOT/core" || exit 1
        echo "building binary..."
        # use `v -o` to compile the main file (build command may behave differently across versions)
        v -o "$ROOT/pueue-mcp" "$ROOT/main.v"
        echo "built $ROOT/pueue-mcp"
        ;;
esac

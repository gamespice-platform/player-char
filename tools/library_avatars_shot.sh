#!/usr/bin/env bash
# Renders the library avatars line-up to out/library_avatars.png (run from the repository root; routes to a GPU box through gpu.sh).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p out
timeout 300 xvfb-run -a godot --path . --resolution 1280x640 --script res://tools/library_avatars_shot.gd -- "${1:-res://out/library_avatars.png}" 2>&1 | grep -E "LIBRARY|ERROR|SCRIPT" || true

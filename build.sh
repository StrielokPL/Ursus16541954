#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
python3 tools/validate_current.py
exec python3 tools/build_mod.py "$@"

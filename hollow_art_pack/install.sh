#!/usr/bin/env bash
set -euo pipefail
PACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${1:-.}"
python3 "$PACK_DIR/install_assets.py" "$PACK_DIR" "$PROJECT_DIR"

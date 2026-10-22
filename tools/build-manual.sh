#!/usr/bin/env bash
#
# Render the repository README.md to Manual.pdf in the repository root.
#
# Usage:
#   ./tools/build-manual.sh [md2pdf options]
#
# Extra arguments are passed through to md2pdf.py, e.g.:
#   ./tools/build-manual.sh --paper Letter
#
set -euo pipefail

if ! command -v uv >/dev/null 2>&1; then
    echo "build-manual: error: 'uv' is required but was not found on PATH" >&2
    exit 127
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"

cd -- "${repo_root}"

exec uv run --script "${script_dir}/md2pdf.py" \
    "${repo_root}/README.md" \
    --output "${repo_root}/Manual.pdf" \
    "$@"

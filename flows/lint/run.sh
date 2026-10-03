#!/usr/bin/env bash
set -euo pipefail

if (( $# < 2 )); then
    echo "Usage: $0 TOP RTL_FILE [RTL_FILE ...]" >&2
    exit 2
fi

top="$1"
shift

command -v verilator >/dev/null || {
    echo "ERROR: Verilator is not installed or activated." >&2
    exit 127
}

out="build/$top/lint"
mkdir -p "$out"

verilator --lint-only --Wall \
    --top-module "$top" "$@" \
    2>&1 | tee "$out/verilator.log"

echo "PASS: Verilator lint completed."

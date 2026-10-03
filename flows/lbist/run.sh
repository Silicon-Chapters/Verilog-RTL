#!/usr/bin/env bash
set -euo pipefail

stage="$(basename "$(dirname "$0")")"

echo "NOT CONFIGURED: $stage" >&2
echo "This stage requires design-specific inputs and implementation." >&2
exit 2

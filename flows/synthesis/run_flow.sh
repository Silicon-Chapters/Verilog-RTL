#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 1 ]]; then
    echo "Usage: $0 configs/DESIGN/config.sh" >&2
    exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$(realpath "$1")"
CONFIG_DIR="$(dirname "$CONFIG_FILE")"

# Defaults may be overridden by the design configuration.
INCLUDE_DIRS=()
EXTRA_MAKE_SETTINGS=()
source "$CONFIG_FILE"

: "${TOP:?Set TOP in config.sh}"
: "${TECHNOLOGY:?Set TECHNOLOGY in config.sh}"
: "${FILELIST:?Set FILELIST in config.sh}"
: "${SDC:?Set SDC in config.sh}"
: "${ORFS_ROOT:?Set ORFS_ROOT in config.sh}"

DOCKER_IMAGE="${DOCKER_IMAGE:-openroad/orfs:latest}"
FLOW_TARGET="${FLOW_TARGET:-floorplan}"

[[ "$TOP" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || {
    echo "ERROR: Unsupported TOP name: $TOP" >&2
    exit 2
}

case "${TECHNOLOGY^^}" in
    NG45|NANGATE45)
        PLATFORM="nangate45"
        ;;
    SKY130|SKY130HD)
        PLATFORM="sky130hd"
        ;;
    *)
        echo "ERROR: TECHNOLOGY must be NG45 or SKY130." >&2
        exit 2
        ;;
esac

case "$FLOW_TARGET" in
    synth|floorplan|finish) ;;
    *)
        echo "ERROR: FLOW_TARGET must be synth, floorplan, or finish." >&2
        exit 2
        ;;
esac

ORFS_ROOT="$(realpath "$ORFS_ROOT")"
FILELIST="$(realpath "$FILELIST")"
SDC="$(realpath "$SDC")"

PLATFORM_DIR="$ORFS_ROOT/flow/platforms/$PLATFORM"

[[ -f "$PLATFORM_DIR/config.mk" ]] || {
    echo "ERROR: Missing platform configuration:" >&2
    echo "$PLATFORM_DIR/config.mk" >&2
    exit 2
}

[[ -f "$FILELIST" && -f "$SDC" ]] || {
    echo "ERROR: FILELIST and SDC must exist." >&2
    exit 2
}

command -v docker >/dev/null || {
    echo "ERROR: Docker is not installed." >&2
    exit 127
}

docker info >/dev/null

for path in "$ROOT" "$ORFS_ROOT" "$FILELIST" "$SDC"; do
    if [[ "$path" =~ [[:space:]] ]]; then
        echo "ERROR: This runner requires paths without whitespace." >&2
        exit 2
    fi
done

RUN_ID="$(date +%Y%m%d_%H%M%S)_$$"
RUN_DIR="$ROOT/build/$TOP/$PLATFORM/$RUN_ID"
mkdir -p "$RUN_DIR"

container_path() {
    local path
    path="$(realpath "$1")"

    case "$path" in
        "$ROOT"/*)
            printf '/workspace/%s' "${path#"$ROOT"/}"
            ;;
        *)
            echo "ERROR: Inputs must be inside $ROOT: $path" >&2
            exit 2
            ;;
    esac
}

SDC_CONTAINER="$(container_path "$SDC")"

sources=()
list_dir="$(dirname "$FILELIST")"

while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"

    [[ -z "$line" || "$line" == \#* ]] && continue
    [[ "$line" == /* ]] || line="$list_dir/$line"

    [[ -f "$line" ]] || {
        echo "ERROR: Missing RTL source: $line" >&2
        exit 2
    }

    if [[ "$line" =~ [[:space:]] ]]; then
        echo "ERROR: Source paths must not contain whitespace." >&2
        exit 2
    fi

    sources+=("$(container_path "$line")")
done < "$FILELIST"

(( ${#sources[@]} > 0 )) || {
    echo "ERROR: No RTL sources found." >&2
    exit 2
}

includes=()
for dir in "${INCLUDE_DIRS[@]}"; do
    [[ -d "$dir" ]] || {
        echo "ERROR: Missing include directory: $dir" >&2
        exit 2
    }

    if [[ "$dir" =~ [[:space:]] ]]; then
        echo "ERROR: Include paths must not contain whitespace." >&2
        exit 2
    fi

    includes+=("$(container_path "$dir")")
done

RUN_CONTAINER="$(container_path "$RUN_DIR")"
DESIGN_CONFIG="$RUN_DIR/design.mk"

# ORFS loads the selected platform's Liberty/LEF configuration.
{
    printf 'export DESIGN_NAME = %s\n' "$TOP"
    printf 'export PLATFORM = %s\n' "$PLATFORM"
    printf 'export FLOW_VARIANT = %s\n' "$RUN_ID"

    printf 'export VERILOG_FILES ='
    printf ' %s' "${sources[@]}"
    printf '\n'

    printf 'export SDC_FILE = %s\n' "$SDC_CONTAINER"

    if (( ${#includes[@]} > 0 )); then
        printf 'export VERILOG_INCLUDE_DIRS ='
        printf ' %s' "${includes[@]}"
        printf '\n'
    fi

    if [[ -n "${DIE_AREA:-}" ]]; then
        printf 'export DIE_AREA = %s\n' "$DIE_AREA"
    fi

    if [[ -n "${CORE_AREA:-}" ]]; then
        printf 'export CORE_AREA = %s\n' "$CORE_AREA"
    fi

    printf 'export PLACE_DENSITY = %s\n' \
        "${PLACE_DENSITY:-0.30}"

    for setting in "${EXTRA_MAKE_SETTINGS[@]}"; do
        printf '%s\n' "$setting"
    done
} > "$DESIGN_CONFIG"

cp "$CONFIG_FILE" "$RUN_DIR/config.snapshot.sh"
cp "$FILELIST" "$RUN_DIR/filelist.snapshot.f"
cp "$SDC" "$RUN_DIR/constraints.snapshot.sdc"
cp "$PLATFORM_DIR/config.mk" "$RUN_DIR/platform.snapshot.mk"

find "$PLATFORM_DIR" -type f \
    \( -name "*.lib" -o -name "*.lib.gz" \
       -o -name "*.lef" -o -name "*.lef.gz" \
       -o -name "*.gds" -o -name "*.tcl" \) \
    | sort > "$RUN_DIR/platform_inventory.txt"

git -C "$ORFS_ROOT" rev-parse HEAD \
    > "$RUN_DIR/orfs_revision.txt"

echo "Design:     $TOP"
echo "Technology: $TECHNOLOGY"
echo "Platform:   $PLATFORM"
echo "Target:     $FLOW_TARGET"
echo "Run:        $RUN_DIR"

docker_args=(
    run --rm
    --user "$(id -u):$(id -g)"
    --volume "$ORFS_ROOT/flow:/OpenROAD-flow-scripts/flow"
    --volume "$ROOT:/workspace"
    --workdir /OpenROAD-flow-scripts/flow
    "$DOCKER_IMAGE"
)

set +e
docker "${docker_args[@]}" \
    make \
    "DESIGN_CONFIG=$RUN_CONTAINER/design.mk" \
    "$FLOW_TARGET" \
    2>&1 | tee "$RUN_DIR/flow.log"

flow_status=${PIPESTATUS[0]}
set -e

printf '%s\n' "$flow_status" > "$RUN_DIR/exit_code.txt"

for category in reports logs results; do
    location="$ORFS_ROOT/flow/$category/$PLATFORM/$TOP/$RUN_ID"

    printf '%s\n' "$location" \
        > "$RUN_DIR/${category}_location.txt"

    if [[ -d "$location" && "$category" != results ]]; then
        mkdir -p "$RUN_DIR/$category"
        cp -a "$location/." "$RUN_DIR/$category/"
    fi
done

echo
echo "Reports: $RUN_DIR"
echo "Physical results:"
cat "$RUN_DIR/results_location.txt"

if (( flow_status != 0 )); then
    echo "FAILED: Flow exited with status $flow_status." >&2
    exit "$flow_status"
fi

echo "COMPLETED: Requested flow target finished."
echo "Review timing, constraint coverage, and diagnostics."

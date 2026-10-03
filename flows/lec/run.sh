#!/usr/bin/env bash
set -euo pipefail

if (( $# != 3 )); then
    echo "Usage: $0 TOP REFERENCE_VERILOG CANDIDATE_VERILOG" >&2
    exit 2
fi

top="$1"
reference="$2"
candidate="$3"

[[ "$top" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || {
    echo "ERROR: Invalid top-module name." >&2
    exit 2
}

[[ -f "$reference" && -f "$candidate" ]] || {
    echo "ERROR: Both input files must exist." >&2
    exit 2
}

command -v yosys >/dev/null || {
    echo "ERROR: Yosys is not installed or activated." >&2
    exit 127
}

out="build/$top/lec"
mkdir -p "$out"

cp -- "$reference" "$out/reference.v"
cp -- "$candidate" "$out/candidate.v"

cat > "$out/run.ys" <<SCRIPT
read_verilog "$out/reference.v"
hierarchy -check -top $top
proc
memory
flatten
rename $top gold
design -stash reference

read_verilog "$out/candidate.v"
hierarchy -check -top $top
proc
memory
flatten
rename $top gate
design -stash candidate

design -reset
design -copy-from reference -as gold gold
design -copy-from candidate -as gate gate

equiv_make gold gate equiv
hierarchy -top equiv
equiv_simple
equiv_induct
equiv_status -assert
SCRIPT

yosys -l "$out/yosys.log" "$out/run.ys"

echo "PASS: Equivalence established by this configured check."

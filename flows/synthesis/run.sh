#!/usr/bin/env bash
set -euo pipefail

if (( $# != 2 )); then
    echo "Usage: $0 TOP RTL_FILE" >&2
    exit 2
fi

top="$1"
rtl="$2"

[[ "$top" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || {
    echo "ERROR: Invalid top-module name." >&2
    exit 2
}

[[ -f "$rtl" ]] || {
    echo "ERROR: RTL file not found: $rtl" >&2
    exit 2
}

command -v yosys >/dev/null || {
    echo "ERROR: Yosys is not installed or activated." >&2
    exit 127
}

out="build/$top/synthesis"
mkdir -p "$out"

# Copy to a predictable path for the generated Yosys script.
cp -- "$rtl" "$out/input.v"

cat > "$out/run.ys" <<SCRIPT
read_verilog "$out/input.v"
hierarchy -check -top $top
synth -top $top
check -assert
tee -o "$out/statistics.txt" stat
write_verilog -noattr "$out/netlist.v"
write_json "$out/netlist.json"
SCRIPT

yosys -l "$out/yosys.log" "$out/run.ys"

echo "PASS: Generic synthesis completed."
echo "Netlist: $out/netlist.v"

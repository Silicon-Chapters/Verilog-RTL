# This file is sourced by run_flow.sh.
# ROOT and CONFIG_DIR are supplied by the runner.

TOP="logic_gates"
FILELIST="$CONFIG_DIR/rtl.f"
OUT_DIR="$ROOT/build/$TOP"

YOSYS_BIN="yosys"
VERILATOR_BIN="verilator"
OPENROAD_BIN="openroad"

# Include directories and preprocessor definitions.
INCLUDE_DIRS=()
DEFINES=()
# Example:
# INCLUDE_DIRS=("$ROOT/common/rtl")
# DEFINES=("FEATURE_ENABLE" "DATA_WIDTH=8")

RUN_LINT=1
MAKE_SCHEMATICS=1

# Empty LIBERTY means generic synthesis.
# Set this to an actual, uncompressed .lib file for cell mapping.
LIBERTY=""

# SDC is used by STA, not by this Yosys synthesis recipe.
SDC=""
RUN_STA=0

# Optional vectorless power estimate:
# requires Liberty power models and an explicit activity assumption.
RUN_POWER=0
POWER_INPUT_ACTIVITY="0.1"

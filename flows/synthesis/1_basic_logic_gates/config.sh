# Loaded by scripts/run_flow.sh.
# ROOT and CONFIG_DIR are provided by that script.

TOP="logic_gates"

# Choose NG45 or SKY130.
TECHNOLOGY="NG45"

FILELIST="$CONFIG_DIR/rtl.f"
SDC="$CONFIG_DIR/timing.sdc"

ORFS_ROOT="$HOME/eda/OpenROAD-flow-scripts"
DOCKER_IMAGE="openroad/orfs:latest"

# synth: library-mapped synthesis and synthesis reports.
# floorplan: also loads LEFs and creates a physical floorplan.
# finish: complete physical flow through final reporting.
FLOW_TARGET="floorplan"

# Use explicit dimensions for this small gates example.
# These are micrometres; change for larger designs.
DIE_AREA="0 0 100 100"
CORE_AREA="10 10 90 90"
PLACE_DENSITY="0.30"

# Optional Verilog include directories.
INCLUDE_DIRS=()

# Additional ORFS settings belong here.
# Example for designs that need specific synthesis definitions:
EXTRA_MAKE_SETTINGS=(
    "export SYNTH_REPEATABLE_BUILD = 1"
)

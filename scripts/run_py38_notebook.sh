#!/usr/bin/env bash
set -e

INPUT="$1"
JOBDIR="$2"

mkdir -p "$JOBDIR"

# Run papermill in the environment that has papermill installed.
# We're calling papermill directly here (assumes papermill available in PATH).
papermill notebooks/OCT_Train_Val_Segmentation.ipynb \
    "${JOBDIR}/oct_out_$(basename "$INPUT").ipynb" \
    -p input_image "$INPUT"

# copy produced output if exists
if [ -d "notebooks/output_oct" ]; then
    mkdir -p "${JOBDIR}/oct_outputs"
    cp -r notebooks/output_oct/* "${JOBDIR}/oct_outputs/" || true
fi

echo "py38 step finished"

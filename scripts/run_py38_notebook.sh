#!/usr/bin/env bash
set -e
INPUT="$1"
JOBDIR="$2"
mkdir -p "$JOBDIR"
# use conda-run if available; papermill should be installed in python38 env
papermill notebooks/OCT_Train_Val_Segmentation.ipynb     "${JOBDIR}/oct_out_$(basename "$INPUT").ipynb"     -k python38 -p input_image "$INPUT"
if [ -d "notebooks/output_oct" ]; then
    mkdir -p "${JOBDIR}/oct_outputs"
    cp -r notebooks/output_oct/* "${JOBDIR}/oct_outputs/" || true
fi
echo "py38 step finished"

#!/usr/bin/env bash
set -e

INPUT="$1"
JOBDIR="$2"

mkdir -p "$JOBDIR"

conda run -n py37 papermill notebooks/pyradiomic.ipynb \
    "${JOBDIR}/pyrad_out_$(basename "$INPUT").ipynb" \
    -k python37 -p input_image "$INPUT"

if [ -d "notebooks/pyradiomic_output" ]; then
    mkdir -p "${JOBDIR}/radiomics_results"
    cp -r notebooks/pyradiomic_output/* "${JOBDIR}/radiomics_results/" || true
fi

echo "py37 step finished"

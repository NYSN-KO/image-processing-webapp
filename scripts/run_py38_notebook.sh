#!/usr/bin/env bash
set -e

INPUT="$1"
JOBDIR="$2"

mkdir -p "$JOBDIR"

conda run -n py38 papermill notebooks/OCT_Train_Val_Segmentation.ipynb \
    "${JOBDIR}/oct_out_$(basename "$INPUT").ipynb" \
    -k python38 -p input_image "$INPUT"

# 如果 notebook 输出到 notebooks/output_oct/ 就复制
if [ -d "notebooks/output_oct" ]; then
    mkdir -p "${JOBDIR}/oct_outputs"
    cp -r notebooks/output_oct/* "${JOBDIR}/oct_outputs/" || true
fi

echo "py38 step finished"

#!/usr/bin/env bash
set -e

INPUT="$1"
MODEL_DIR="$2"
JOBDIR="$3"

mkdir -p "$JOBDIR"

Rscript r/run_R_from_txt.R "$INPUT" "$MODEL_DIR"

# copy radiomics_outputs if exists
if [ -d "radiomics_results" ]; then
    mkdir -p "${JOBDIR}/radiomics_results"
    cp -r radiomics_results/* "${JOBDIR}/radiomics_results/" || true
fi

echo "R step finished"

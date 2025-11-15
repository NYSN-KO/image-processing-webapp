#!/usr/bin/env bash
# run_r.sh <input_image> <model_dir> <job_dir>
set -e
INPUT="$1"
MODEL_DIR="$2"
JOBDIR="$3"
mkdir -p "$JOBDIR"
# Run your R wrapper, pass input and model dir and ensure R writes outputs into JOBDIR/radiomics_results or similar.
# Here we call the script and pass jobdir as third arg if script supports it; your current R script expects input_image, model_dir
Rscript r/run_R_from_txt.R "$INPUT" "$MODEL_DIR"
# If R script writes results into a known folder, move them into JOBDIR
# Example: if R writes into root_dir used inside script, we assume it wrote into a folder under MODEL_DIR or working dir
# Try move common outputs to job dir
if [ -d "radiomics_results" ]; then
  mkdir -p "${JOBDIR}/radiomics_results"
  cp -r radiomics_results/* "${JOBDIR}/radiomics_results/" || true
fi
echo "R step finished; check logs for details. jobdir=${JOBDIR}"

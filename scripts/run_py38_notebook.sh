#!/usr/bin/env bash
# run_py38_notebook.sh <input_image> <job_dir>
set -e
INPUT="$1"
JOBDIR="$2"
mkdir -p "$JOBDIR"
# run papermill with python3.8 kernel (kernel name should be python38)
/opt/py38/bin/papermill notebooks/OCT_Train_Val_Segmentation.ipynb "${JOBDIR}/out_oct_$(basename "$INPUT").ipynb" -k python38 -p input_image "$INPUT"
# If your notebook writes outputs to a fixed folder, copy them into JOBDIR
# Example: if notebook writes to notebooks/output_oct/, copy:
if [ -d "notebooks/output_oct" ]; then
  mkdir -p "${JOBDIR}/oct_outputs"
  cp -r notebooks/output_oct/* "${JOBDIR}/oct_outputs/" || true
fi
echo "py38 done, outputs copied to ${JOBDIR}"


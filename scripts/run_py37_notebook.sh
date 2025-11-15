#!/usr/bin/env bash
# run_py37_notebook.sh <input_image> <job_dir>
set -e
INPUT="$1"
JOBDIR="$2"
mkdir -p "$JOBDIR"
# run papermill with python3.7 kernel (kernel name should be python37)
/opt/py37/bin/papermill notebooks/pyradiomic.ipynb "${JOBDIR}/out_pyrad_$(basename "$INPUT").ipynb" -k python37 -p input_image "$INPUT"
# copy pyradiomic outputs (feature matrices) into jobdir/radiomics_results
# Adjust SOURCE_DIR below if your notebook writes to another location
SOURCE_DIR="notebooks/pyradiomic_output"
if [ -d "$SOURCE_DIR" ]; then
  mkdir -p "${JOBDIR}/radiomics_results"
  cp -r "${SOURCE_DIR}/"* "${JOBDIR}/radiomics_results/" || true
fi
# sometimes pyradiomic writes directly into current dir; try copy common names
for f in X_train_*.csv X_test_*.csv; do
  if ls $f 1> /dev/null 2>&1; then
    mkdir -p "${JOBDIR}/radiomics_results"
    cp $f "${JOBDIR}/radiomics_results/" || true
  fi
done
echo "py37 done, radiomics outputs (if any) copied to ${JOBDIR}/radiomics_results"

#!/bin/bash
INPUT=$1
/opt/py37/bin/papermill notebooks/pyradiomic.ipynb notebooks/out_pyrad_$(basename "$INPUT").ipynb -p input_image "$INPUT"

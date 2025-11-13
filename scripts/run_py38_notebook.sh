#!/bin/bash
INPUT=$1
/opt/py38/bin/papermill notebooks/OCT_Train_Val_Segmentation.ipynb notebooks/out_oct_$(basename "$INPUT").ipynb -p input_image "$INPUT"

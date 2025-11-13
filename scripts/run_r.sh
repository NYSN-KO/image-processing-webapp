#!/bin/bash
INPUT=$1
MODEL_DIR=$2
Rscript r/run_R_from_txt.R "$INPUT" "$MODEL_DIR"

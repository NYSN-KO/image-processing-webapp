#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly=TRUE)
if (length(args) < 2) {
  stop('Usage: Rscript run_R_from_txt.R <input_image_path> <model_dir>')
}
input_image <- args[1]
model_dir <- args[2]

suppressPackageStartupMessages({
  library(data.table)
  library(dplyr)
  library(ggplot2)
})

# try to find radiomics csv produced by py37
stem <- tools::file_path_sans_ext(basename(input_image))
rad_dir <- "notebooks/pyradiomic_output"
files <- list.files(rad_dir, pattern = paste0("radiomics_", stem, ".*csv$"), full.names = TRUE)
if (length(files) == 0) {
  stop(paste("No radiomics CSV found for", stem, "in", rad_dir))
}
rad_csv <- files[1]
cat("Found radiomics CSV:", rad_csv, "\n")

# load
df <- fread(rad_csv)
# --- place your original analysis code here ---
# For now, just save a copy into radiomics_results for the pipeline to collect
out_dir <- "radiomics_results"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
out_path <- file.path(out_dir, paste0("r_processed_", stem, ".csv"))
fwrite(df, out_path)
cat("R step finished, wrote", out_path, "\n")

# ---------------------------------------------------------
# 1) Base image
# ---------------------------------------------------------
FROM continuumio/miniconda3:latest

# ---------------------------------------------------------
# 2) OS dependencies
# ---------------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl wget git nano gcc g++ make build-essential \
        libgl1-mesa-glx libglib2.0-0 dos2unix && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------
# 3) Create environments
# ---------------------------------------------------------
RUN conda create -n py37 python=3.7 -y && \
    conda create -n py38 python=3.8 -y && \
    conda create -n r_env -c conda-forge -y r-base=4.2.0 r-tidyverse r-jsonlite

# ---------------------------------------------------------
# 4) Install Python 3.7 packages
# ---------------------------------------------------------
RUN conda run -n py37 pip install --no-cache-dir \
    numpy==1.21.0 \
    SimpleITK==2.2.1 \
    pyradiomics==3.0.1

# ---------------------------------------------------------
# 5) Install Python 3.8 packages
# ---------------------------------------------------------
RUN conda run -n py38 pip install --no-cache-dir \
    torch==2.4.1 \
    torchvision==0.19.1 \
    segmentation-models-pytorch==0.3.3 \
    numpy==1.24.4 \
    pillow \
    opencv-python-headless

# ---------------------------------------------------------
# 6) Set working directory
# ---------------------------------------------------------
WORKDIR /app

# ---------------------------------------------------------
# 7) Copy source files
# ---------------------------------------------------------
COPY app.py /app/app.py
COPY static/ /app/static/
COPY models/ /app/models/
COPY notebooks/ /app/notebooks/
CO

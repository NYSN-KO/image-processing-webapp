# ---------------------------------------------------------
# 1. Base image：Miniconda3 (Render 100% 兼容版本)
# ---------------------------------------------------------
FROM continuumio/miniconda3:latest

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl wget git nano gcc g++ make build-essential \
        libgl1-mesa-glx libglib2.0-0 dos2unix && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ---------------------------------------------------------
# Python 3.7
# ---------------------------------------------------------
RUN conda create -n py37 python=3.7 -y
RUN conda run -n py37 pip install --no-cache-dir \
        numpy==1.21.0 \
        SimpleITK==2.2.1 \
        pyradiomics==3.0.1

# ---------------------------------------------------------
# Python 3.8
# ---------------------------------------------------------
RUN conda create -n py38 python=3.8 -y
RUN conda run -n py38 pip install --no-cache-dir \
        torch==2.4.1 \
        torchvision==0.19.1 \
        segmentation-models-pytorch==0.3.3 \
        numpy==1.24.4 \
        pillow \
        opencv-python-headless

# ---------------------------------------------------------
# R
# ---------------------------------------------------------
RUN conda create -n r_env -c conda-forge -y r-base=4.2.0 r-tidyverse r-jsonlite

# ---------------------------------------------------------
# Copy files
# ---------------------------------------------------------
COPY app.py /app/app.py
COPY static/ /app/static/
COPY uploads/ /app/uploads/
COPY scripts/ /app/scripts/

# ---------------------------------------------------------
# Script permissions
# ---------------------------------------------------------
RUN dos2unix /app/scripts/*.sh || true
RUN chmod +x /app/scripts/*.sh

# ---------------------------------------------------------
# Flask
# ---------------------------------------------------------
RUN pip install --no-cache-dir flask werkzeug==2.2.2

EXPOSE 8000

CMD ["python", "app.py"]

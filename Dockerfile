# ---------------------------------------------------------
# 1. Base image：Miniconda（稳定 & 全球可访问）
# ---------------------------------------------------------
FROM continuumio/miniconda3:latest

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /app

# ---------------------------------------------------------
# 2. Install system dependencies
# ---------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl wget git nano gcc g++ make build-essential \
    libgl1-mesa-glx libglib2.0-0 dos2unix && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------
# 3. Create environments
# ---------------------------------------------------------
RUN conda create -n py37 python=3.7 -y && \
    conda create -n py38 python=3.8 -y && \
    conda create -n r_env -c conda-forge -y r-base=4.2.0 r-tidyverse r-jsonlite

# ---------------------------------------------------------
# 4. Install deps
# ---------------------------------------------------------
COPY requirements_py37.txt /app/
COPY requirements_py38.txt /app/

RUN conda run -n py37 pip install --no-cache-dir SimpleITK==2.2.1 pyradiomics==3.0.1 && \
    conda run -n py37 pip install --no-cache-dir -r requirements_py37.txt

RUN conda run -n py38 pip install --no-cache-dir -r requirements_py38.txt

RUN pip install flask papermill notebook nbformat nbconvert

# ---------------------------------------------------------
# 5. Copy project files
# ---------------------------------------------------------
COPY static/ /app/static/
COPY models/ /app/models/
COPY scripts/ /app/scripts/
COPY r/ /app/r/
COPY notebooks/ /app/notebooks/
COPY original_notebooks/ /app/original_notebooks/

RUN chmod +x /app/scripts/*.sh && dos2unix /app/scripts/*.sh

COPY app.py /app/app.py

# ---------------------------------------------------------
# 6. Start service
# ---------------------------------------------------------
EXPOSE 8000
CMD ["python", "app.py"]

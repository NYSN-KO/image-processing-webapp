FROM ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------
# 1. System packages
# ------------------------------------------------------
RUN apt-get update --yes && apt-get install -y --no-install-recommends \
    python3.8 python3.8-venv python3.8-dev python3-pip \
    build-essential wget curl ca-certificates ffmpeg libsm6 libxext6 libgl1-mesa-glx \
    r-base r-base-core git cmake ninja-build \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ------------------------------------------------------
# 2. Install Miniconda
# ------------------------------------------------------
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh && \
    bash miniconda.sh -b -p /opt/conda && rm miniconda.sh

ENV PATH=/opt/conda/bin:$PATH

# ------------------------------------------------------
# 3. Accept ToS (prevent error)
# ------------------------------------------------------
RUN conda config --set channel_priority flexible && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

# ------------------------------------------------------
# 4. Create conda envs
# ------------------------------------------------------
RUN conda update -n base -c defaults conda -y && \
    conda create -n py38 python=3.8 -y && \
    conda create -n py37 python=3.7 -y

# ------------------------------------------------------
# 5. Install Python dependencies
# ------------------------------------------------------

# SimpleITK must use conda
RUN conda install -n py37 -c simpleitk simpleitk==2.2.1 -y

# pyradiomics must use pip (not available in conda)
RUN conda run -n py37 pip install pyradiomics

COPY requirements_py37.txt /tmp/req37.txt
COPY requirements_py38.txt /tmp/req38.txt

RUN conda run -n py37 pip install --no-cache-dir -r /tmp/req37.txt
RUN conda run -n py38 pip install --no-cache-dir -r /tmp/req38.txt

# Flask (backend) must be installed into py38 (app environment)
RUN conda run -n py38 pip install flask pillow numpy

# ------------------------------------------------------
# 6. Make py38 the default runtime environment
# ------------------------------------------------------
ENV PATH=/opt/conda/envs/py38/bin:$PATH

# ------------------------------------------------------
# 7. Copy project files
# ------------------------------------------------------
COPY . /app

EXPOSE 10000

# ------------------------------------------------------
# 8. Use py38 to run Flask app
# ------------------------------------------------------
CMD ["python", "app.py"]

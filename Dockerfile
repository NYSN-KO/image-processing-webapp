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
# 3. Accept ToS
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
# 5. Install SimpleITK (pyradiomics MUST be pip)
# ------------------------------------------------------
RUN conda install -n py37 -c simpleitk simpleitk=2.2.1 -y

# PIP INSTALL pyradiomics (conda 没有 py37 版本)
RUN conda run -n py37 pip install pyradiomics

# ------------------------------------------------------
# 6. Python requirements
# ------------------------------------------------------
COPY requirements_py37.txt /tmp/req37.txt
COPY requirements_py38.txt /tmp/req38.txt

RUN conda run -n py37 pip install --no-cache-dir -r /tmp/req37.txt
RUN conda run -n py38 pip install --no-cache-dir -r /tmp/req38.txt

# ------------------------------------------------------
# 7. Fix script permissions
# ------------------------------------------------------
RUN chmod +x /app/scripts/run_py37_notebook.sh && \
    chmod +x /app/scripts/run_py38_notebook.sh && \
    chmod +x /app/scripts/run_r.sh

# ------------------------------------------------------
# 8. Install Flask into python3.8 (Render uses CMD python3.8)
# ------------------------------------------------------
RUN pip install flask pillow numpy

# ------------------------------------------------------
# 9. Copy project files
# ------------------------------------------------------
COPY . /app

# ------------------------------------------------------
# 10. Run
# ------------------------------------------------------
EXPOSE 10000
CMD ["python3.8", "app.py"]

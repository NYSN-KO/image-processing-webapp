FROM ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /app

# ------------------------------------------------------
# 1. Install system packages
# ------------------------------------------------------
RUN apt-get update --yes && apt-get install -y --no-install-recommends \
    python3.8 python3.8-venv python3.8-dev python3-pip \
    build-essential wget curl ca-certificates ffmpeg libsm6 libxext6 libgl1-mesa-glx \
    r-base r-base-core \
    git cmake ninja-build \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------
# 2. Install Miniconda
# ------------------------------------------------------
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh && \
    bash miniconda.sh -b -p /opt/conda && rm miniconda.sh

ENV PATH=/opt/conda/bin:$PATH

# ------------------------------------------------------
# 3. Accept Anaconda TOS (avoid build failure)
# ------------------------------------------------------
RUN conda config --set channel_priority flexible && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

# ------------------------------------------------------
# 4. Create Python environments
# ------------------------------------------------------
RUN conda update -n base -c defaults conda -y && \
    conda create -n py38 python=3.8 -y && \
    conda create -n py37 python=3.7 -y

# ------------------------------------------------------
# 5. Install packages for py37 (SimpleITK + pyradiomics)
# ------------------------------------------------------
RUN conda run -n py37 pip install --no-cache-dir SimpleITK==2.2.1 pyradiomics

# ------------------------------------------------------
# 6. Copy requirements and install pip dependencies
# ------------------------------------------------------
COPY requirements_py37.txt /tmp/req37.txt
COPY requirements_py38.txt /tmp/req38.txt

RUN conda run -n py37 pip install --no-cache-dir -r /tmp/req37.txt
RUN conda run -n py38 pip install --no-cache-dir -r /tmp/req38.txt

# ------------------------------------------------------
# 7. Copy all project files
# ------------------------------------------------------
COPY . /app

# ------------------------------------------------------
# 8. Copy scripts directory (VERY IMPORTANT!!)
# ------------------------------------------------------
COPY scripts/ /scripts/

# ------------------------------------------------------
# 9. Give execution permission
# ------------------------------------------------------
RUN chmod +x /scripts/run_py37_notebook.sh && \
    chmod +x /scripts/run_py38_notebook.sh && \
    chmod +x /scripts/run_r.sh

# ------------------------------------------------------
# 10. Install Flask into system Python (for Render entry)
# ------------------------------------------------------
RUN pip install flask pillow numpy

# ------------------------------------------------------
# 11. Expose port
# ------------------------------------------------------
EXPOSE 10000

# ------------------------------------------------------
# 12. Default command: run app.py with Python3.8
# ------------------------------------------------------
CMD ["python3.8", "app.py"]

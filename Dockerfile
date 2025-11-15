FROM ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------
# 1. Install basic system packages (NO python3.7 here!)
# ------------------------------------------------------
RUN apt-get update --yes && apt-get install -y --no-install-recommends \
    python3.8 python3.8-venv python3.8-dev python3-pip \
    build-essential wget curl ca-certificates ffmpeg libsm6 libxext6 libgl1-mesa-glx \
    r-base r-base-core \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ------------------------------------------------------
# 2. Install Miniconda (will be used to provide Python 3.7)
# ------------------------------------------------------
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh && \
    bash miniconda.sh -b -p /opt/conda && \
    rm miniconda.sh
ENV PATH=/opt/conda/bin:$PATH

# ------------------------------------------------------
# 3. Create conda environments: py38 & py37
# ------------------------------------------------------
RUN conda update -n base -c defaults conda -y && \
    conda create -n py38 python=3.8 -y && \
    conda create -n py37 python=3.7 -y 

# ------------------------------------------------------
# 4. Install Python packages
# ------------------------------------------------------
COPY requirements_py37.txt /tmp/req37.txt
COPY requirements_py38.txt /tmp/req38.txt

RUN conda run -n py37 pip install --no-cache-dir -r /tmp/req37.txt
RUN conda run -n py38 pip install --no-cache-dir -r /tmp/req38.txt

# ------------------------------------------------------
# 5. Copy project files
# ------------------------------------------------------
COPY . /app

# ------------------------------------------------------
# 6. Expose and start
# ------------------------------------------------------
EXPOSE 10000
CMD ["python3.8", "app.py"]


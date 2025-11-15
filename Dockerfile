FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# Install system deps
RUN apt-get update && apt-get install -y \
    wget curl git build-essential ca-certificates \
    r-base \
    libssl-dev libxml2-dev libcurl4-openssl-dev libjpeg-dev zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Miniconda
ENV CONDA_DIR=/opt/conda
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/conda.sh && \
    bash /tmp/conda.sh -b -p $CONDA_DIR && \
    rm /tmp/conda.sh
ENV PATH=$CONDA_DIR/bin:$PATH

# ⭐⭐ 必须接受 Conda TOS，不然不能创建 py37
RUN conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

# Create Python 3.7 and 3.8 environments
RUN conda create -y -n py37 python=3.7 && conda create -y -n py38 python=3.8

# Install pip packages
COPY requirements_py37.txt /tmp/req37.txt
COPY requirements_py38.txt /tmp/req38.txt

RUN conda run -n py37 pip install -r /tmp/req37.txt
RUN conda run -n py38 pip install -r /tmp/req38.txt

# Install papermill + Jupyter kernels for py38
RUN conda install -y -n py38 ipykernel && \
    conda run -n py38 pip install papermill && \
    conda run -n py38 python -m ipykernel install --user --name python38 --display-name "Python 3.8"


RUN conda install -y -n py37 ipykernel && \
    conda run -n py37 python -m ipykernel install --user --name python37 --display-name "Python 3.7"

# Set workdir
WORKDIR /app

# Copy whole project
COPY . /app

# 🔥 FIX: give execute permission to .sh scripts
RUN chmod +x /app/scripts/*.sh

# Flask must run in py38
RUN conda run -n py38 pip install flask

EXPOSE 10000

CMD ["conda", "run", "--no-capture-output", "-n", "py38", "python", "app.py"]

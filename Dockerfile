FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# -------------------------------
# 1. Install system deps
# -------------------------------
RUN apt-get update && apt-get install -y \
    wget curl git build-essential ca-certificates \
    libssl-dev libxml2-dev libcurl4-openssl-dev libjpeg-dev zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# -------------------------------
# 2. Install Miniconda
# -------------------------------
ENV CONDA_DIR=/opt/conda
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/conda.sh && \
    bash /tmp/conda.sh -b -p $CONDA_DIR && \
    rm /tmp/conda.sh
ENV PATH=$CONDA_DIR/bin:$PATH

# -------------------------------
# 3. Accept Anaconda Terms of Service (MUST HAVE)
# -------------------------------
RUN conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

# -------------------------------
# 4. Add channels
# -------------------------------
RUN conda config --add channels https://repo.anaconda.com/pkgs/main && \
    conda config --add channels https://repo.anaconda.com/pkgs/r

# -------------------------------
# 5. Create Python 3.7 + 3.8 envs
# -------------------------------
RUN conda create -y -n py37 python=3.7 && \
    conda create -y -n py38 python=3.8

# -------------------------------
# 6. Install pip packages
# -------------------------------
COPY requirements_py37.txt /tmp/req37.txt
COPY requirements_py38.txt /tmp/req38.txt

RUN conda run -n py37 pip install -r /tmp/req37.txt
RUN conda run -n py38 pip install -r /tmp/req38.txt

# -------------------------------
# 7. Install papermill + jupyter + ipykernel in py38
# -------------------------------
RUN conda run -n py38 pip install papermill jupyter && \
    conda run -n py38 python -m ipykernel install --user --name python38 --display-name "Python 3.8"

# -------------------------------
# 8. Install papermill + jupyter + ipykernel in py37
# -------------------------------
RUN conda run -n py37 pip install papermill jupyter && \
    conda run -n py37 python -m ipykernel install --user --name python37 --display-name "Python 3.7"

# -------------------------------
# 9. Set working directory
# -------------------------------
WORKDIR /app

# -------------------------------
# 10. Copy entire project
# -------------------------------
COPY . /app

# -------------------------------
# 11. Fix permissions for scripts
# -------------------------------
RUN chmod +x /app/scripts/*.sh

# -------------------------------
# 12. Install flask in py38
# -------------------------------
RUN conda run -n py38 pip install flask

EXPOSE 8000

# -------------------------------
# 13. Launch with py38
# -------------------------------
CMD ["conda", "run", "--no-capture-output", "-n", "py38", "python", "app.py"]

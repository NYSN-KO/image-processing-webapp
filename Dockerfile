FROM ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------
# 1. Install system packages
# ------------------------------------------------------
RUN apt-get update --yes && apt-get install -y --no-install-recommends \
    python3.8 python3.8-venv python3.8-dev python3-pip \
    build-essential wget curl ca-certificates ffmpeg libsm6 libxext6 libgl1-mesa-glx \
    r-base r-base-core \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ------------------------------------------------------
# 2. Install Miniconda
# ------------------------------------------------------
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh && \
    bash miniconda.sh -b -p /opt/conda && rm miniconda.sh

ENV PATH=/opt/conda/bin:$PATH

# ------------------------------------------------------
# 3. Accept Anaconda Terms of Service (fix TOS error)
# ------------------------------------------------------
RUN echo "channels:" > /opt/conda/.condarc && \
    echo "  - defaults" >> /opt/conda/.condarc && \
    echo "channel_priority: flexible" >> /opt/conda/.condarc && \
    echo "tos:" >> /opt/conda/.condarc && \
    echo "  accepted: true" >> /opt/conda/.condarc

# ------------------------------------------------------
# 4. Create conda environments
# ------------------------------------------------------
RUN conda update -n base -c defaults conda -y && \
    conda create -n py38 python=3.8 -y && \
    conda create -n py37 python=3.7 -y

# ------------------------------------------------------
# 5. Install Python dependencies
# ------------------------------------------------------
COPY requirements_py37.txt /tmp/req37.txt
COPY requirements_py38.txt /tmp/req38.txt

RUN conda run -n py37 pip install --no-cache-dir -r /tmp/req37.txt
RUN conda run -n py38 pip install --no-cache-dir -r /tmp/req38.txt

# ------------------------------------------------------
# 6. Copy all project files
# ------------------------------------------------------
COPY . /app

EXPOSE 10000
CMD ["python3.8", "app.py"]

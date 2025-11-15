FROM ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------
# 1. 系统依赖 + R
# ------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    python3.8 python3.8-venv python3.8-dev python3-pip \
    build-essential wget curl ca-certificates ffmpeg libsm6 libxext6 libgl1-mesa-glx \
    r-base r-base-core \
    git cmake ninja-build \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ------------------------------------------------------
# 2. Miniconda
# ------------------------------------------------------
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh && \
    bash miniconda.sh -b -p /opt/conda && rm miniconda.sh

ENV PATH=/opt/conda/bin:$PATH

# ------------------------------------------------------
# 3. Conda TOS
# ------------------------------------------------------
RUN conda config --set channel_priority flexible && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main && \
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

# ------------------------------------------------------
# 4. 创建环境
# ------------------------------------------------------
RUN conda update -n base -c defaults conda -y && \
    conda create -n py38 python=3.8 -y && \
    conda create -n py37 python=3.7 -y

# ------------------------------------------------------
# 5. py37: SimpleITK + pyradiomics
# ------------------------------------------------------
RUN conda install -n py37 -c simpleitk simpleitk==2.2.1 -y
RUN conda run -n py37 pip install pyradiomics

# ------------------------------------------------------
# 6. 安装项目依赖
# ------------------------------------------------------
COPY requirements_py37.txt /tmp/req37.txt
COPY requirements_py38.txt /tmp/req38.txt

RUN conda run -n py37 pip install --no-cache-dir -r /tmp/req37.txt
RUN conda run -n py38 pip install --no-cache-dir -r /tmp/req38.txt

# ------------------------------------------------------
# 7. 在 py38 环境安装 Flask（最关键）
# ------------------------------------------------------
RUN conda run -n py38 pip install flask pillow numpy

# ------------------------------------------------------
# 8. 复制项目文件
# ------------------------------------------------------
COPY . /app

# ------------------------------------------------------
# 9. 用 conda py38 运行应用
# ------------------------------------------------------
EXPOSE 10000
CMD ["conda", "run", "--no-capture-output", "-n", "py38", "python", "app.py"]

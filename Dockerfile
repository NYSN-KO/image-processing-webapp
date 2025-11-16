FROM continuumio/miniconda3:4.12.0

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /app

# ------------------------------------------------------
# 1) Install system packages + R (合并到一个 RUN 更快)
# ------------------------------------------------------
RUN apt-get update --yes && \
    apt-get install -y --no-install-recommends \
        build-essential \
        r-base r-base-core \
        ffmpeg libsm6 libxext6 libgl1-mesa-glx \
        git cmake ninja-build \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------
# 2) Create Python envs (极简 + 快)
# ------------------------------------------------------
RUN conda create -n py38 python=3.8 -y && \
    conda create -n py37 python=3.7 -y

# ------------------------------------------------------
# 3) Install SimpleITK + pyradiomics (用 pip 是最快 & 最稳)
# ------------------------------------------------------
RUN conda run -n py37 pip install --no-cache-dir SimpleITK==2.2.1 pyradiomics

# ------------------------------------------------------
# 4) Install project python deps
# ------------------------------------------------------
COPY requirements_py37.txt /tmp/req37.txt
COPY requirements_py38.txt /tmp/req38.txt

RUN conda run -n py37 pip install --no-cache-dir -r /tmp/req37.txt && \
    conda run -n py38 pip install --no-cache-dir -r /tmp/req38.txt

# ------------------------------------------------------
# 5) Copy project source code
# ------------------------------------------------------
COPY . /app

# ------------------------------------------------------
# 6) Copy scripts folder (正确路径！！！)
# ------------------------------------------------------
COPY scripts/ /scripts/

RUN chmod +x /scripts/run_py37_notebook.sh && \
    chmod +x /scripts/run_py38_notebook.sh && \
    chmod +x /scripts/run_r.sh

# ------------------------------------------------------
# 7) Install Flask into base Python (Render 入口)
# ------------------------------------------------------
RUN pip install flask pillow numpy

EXPOSE 10000

# ------------------------------------------------------
# 8) Start API using system python (稳定)
# ------------------------------------------------------
CMD ["python", "app.py"]

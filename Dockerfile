###########################################
# Stage 1 — Builder（Mamba 超高速构建环境）
###########################################
FROM mambaorg/micromamba:1.5.8 AS builder

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /build

USER root

# 必要系统依赖
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl wget git nano dos2unix build-essential \
        libgl1-mesa-glx libglib2.0-0 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 复制 requirements（尽早以利用缓存）
COPY requirements_py37.txt requirements_py38.txt /build/

###########################################
# 创建三个环境：py37 / py38 / R
# （必须添加 defaults，否则 python=3.7 无法安装）
###########################################
RUN micromamba create -y -n py37 python=3.7 \
        --channel conda-forge --channel defaults && \
    micromamba create -y -n py38 python=3.8 \
        --channel conda-forge --channel defaults && \
    micromamba create -y -n r_env \
        -c conda-forge r-base=4.2.0 r-tidyverse r-jsonlite && \
    micromamba clean --all --yes

###########################################
# 安装 py37 依赖
###########################################
RUN micromamba run -n py37 pip install --no-cache-dir \
        SimpleITK==2.2.1 pyradiomics==3.0.1 && \
    micromamba run -n py37 pip install --no-cache-dir \
        -r /build/requirements_py37.txt

###########################################
# 安装 py38 依赖
###########################################
RUN micromamba run -n py38 pip install --no-cache-dir \
        -r /build/requirements_py38.txt

###########################################
# base 环境安装 Flask / Papermill
###########################################
RUN micromamba install -n base -y pip && \
    pip install --no-cache-dir flask papermill nbformat nbconvert notebook



###########################################
# Stage 2 — Runtime（精简镜像）
###########################################
FROM mambaorg/micromamba:1.5.8

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /app
USER root

# 拷贝构建好的 Conda 环境
COPY --from=builder /opt/conda /opt/conda
ENV PATH=/opt/conda/bin:$PATH

# 创建 uploads 文件夹（无需 COPY）
RUN mkdir -p /app/uploads

###########################################
# 复制项目文件
###########################################
COPY static/ /app/static/
COPY models/ /app/models/
COPY scripts/ /app/scripts/
COPY r/ /app/r/
COPY notebooks/ /app/notebooks/
COPY original_notebooks/ /app/original_notebooks/
COPY app.py /app/app.py

# 修复脚本权限
RUN if [ -d /app/scripts ]; then \
      chmod +x /app/scripts/*.sh 2>/dev/null || true ; \
      find /app/scripts -type f -exec dos2unix {} \; 2>/dev/null || true ; \
    fi

EXPOSE 8000

###########################################
# 默认运行 Flask（使用 py38）
###########################################
CMD ["micromamba", "run", "-n", "py38", "python", "app.py"]

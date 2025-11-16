###########################################
# Stage 1 — Builder（使用 Mamba 超高速构建环境）
###########################################
FROM mambaorg/micromamba:1.5.8 as builder

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /build

# 准备 micromamba 环境
USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl wget git ca-certificates dos2unix nano build-essential \
        libgl1-mesa-glx libglib2.0-0 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 复制 requirements（越早越能利用缓存）
COPY requirements_py37.txt requirements_py38.txt /build/

# 用 micromamba 创建全部环境（1 步完成，极大加速）
RUN micromamba create -y -n py37 python=3.7 && \
    micromamba create -y -n py38 python=3.8 && \
    micromamba create -y -n r_env -c conda-forge \
        r-base=4.2.0 r-tidyverse r-jsonlite && \
    micromamba clean --all --yes

# 安装 py37 heavy deps
RUN micromamba run -n py37 pip install --no-cache-dir \
        SimpleITK==2.2.1 \
        pyradiomics==3.1.0 && \
    micromamba run -n py37 pip install --no-cache-dir \
        -r /build/requirements_py37.txt

# 安装 py38 deps
RUN micromamba run -n py38 pip install --no-cache-dir \
        -r /build/requirements_py38.txt

# base 环境安装 Flask / papermill（避免 app.py ImportError）
RUN micromamba install -n base -y pip && \
    pip install --no-cache-dir flask papermill nbformat nbconvert notebook


###########################################
# Stage 2 — Runtime（极小的最终镜像）
###########################################
FROM mambaorg/micromamba:1.5.8

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /app
USER root

# 拷贝构建好的 conda 环境（秒级加载）
COPY --from=builder /opt/conda /opt/conda

ENV PATH=/opt/conda/bin:$PATH

# 创建 uploads（不需要 COPY uploads/）
RUN mkdir -p /app/uploads

# 复制项目文件
COPY static/ /app/static/
COPY models/ /app/models/
COPY scripts/ /app/scripts/
COPY r/ /app/r/
COPY notebooks/ /app/notebooks/
COPY original_notebooks/ /app/original_notebooks/
COPY app.py /app/app.py

# 脚本权限（容错）
RUN if [ -d /app/scripts ]; then \
      chmod +x /app/scripts/*.sh 2>/dev/null || true ; \
      find /app/scripts -type f -exec dos2unix {} \; 2>/dev/null || true ; \
    fi

# Render 使用 8000
EXPOSE 8000

# 让 Flask 运行在 py38（你要求 ALL，都做了）
CMD ["micromamba", "run", "-n", "py38", "python", "app.py"]

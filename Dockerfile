# ---------------------------------------------------------
# 1. Base image：Miniconda（稳定 & Render 最兼容）
# ---------------------------------------------------------
FROM continuumio/miniconda3:23.5.2

# ---------------------------------------------------------
# 2. APT 加速 + 必要依赖（轻量）
# ---------------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl wget git nano gcc g++ make build-essential \
        libgl1-mesa-glx libglib2.0-0 dos2unix && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ---------------------------------------------------------
# 3. 创建 Conda 环境（提前执行以最大利用缓存）
# ---------------------------------------------------------
RUN conda create -n py37 python=3.7 -y
RUN conda create -n py38 python=3.8 -y
RUN conda create -n r_env -c conda-forge -y r-base=4.2.0 r-tidyverse r-jsonlite

# ---------------------------------------------------------
# 4. 安装 Python 依赖（严格指定版本 → 快速缓存）
# ---------------------------------------------------------
RUN conda run -n py37 pip install --no-cache-dir \
    numpy==1.21.0 \
    SimpleITK==2.2.1 \
    pyradiomics==3.0.1

RUN conda run -n py38 pip install --no-cache-dir \
    torch==2.4.1 \
    torchvision==0.19.1 \
    segmentation-models-pytorch==0.3.3 \
    numpy==1.24.4 \
    pillow \
    opencv-python-headless

# Flask 安装在 base 环境（给 app.py）
RUN pip install flask

# ---------------------------------------------------------
# 5. 复制项目文件（顺序极其重要，保证缓存最大化）
# ---------------------------------------------------------

# 先复制变化少的（提高缓存命中率）
COPY static/ /app/static/
COPY models/ /app/models/
COPY scripts/ /app/scripts/
COPY r/ /app/r/
COPY notebooks/ /app/notebooks/
COPY original_notebooks/ /app/original_notebooks/

# 确保脚本可执行
RUN chmod +x /app/scripts/*.sh && dos2unix /app/scripts/*.sh

# 再复制变化较大的（减少构建失效概率）
COPY app.py /app/app.py

# ---------------------------------------------------------
# 6. 运行 Flask —— 使用 base env（无冲突）
# ---------------------------------------------------------
EXPOSE 8000
CMD ["python", "app.py"]

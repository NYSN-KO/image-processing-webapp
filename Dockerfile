# ---------------------------------------------------------
# 1. Base image：Miniconda3 (最稳定，兼容 Render)
# ---------------------------------------------------------
FROM continuumio/miniconda3:23.10.0

# 加速 APT（必须）
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl wget git nano gcc g++ make build-essential \
        libgl1-mesa-glx libglib2.0-0 dos2unix && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------
# 2. 创建工作目录
# ---------------------------------------------------------
WORKDIR /app

# ---------------------------------------------------------
# 3. 创建 Python 3.7 环境
# ---------------------------------------------------------
RUN conda create -n py37 python=3.7 -y
RUN conda run -n py37 pip install --no-cache-dir \
        numpy==1.21.0 \
        SimpleITK==2.2.1 \
        pyradiomics==3.0.1

# ---------------------------------------------------------
# 4. Python 3.8 环境（用于 segmentation models）
# ---------------------------------------------------------
RUN conda create -n py38 python=3.8 -y
RUN conda run -n py38 pip install --no-cache-dir \
        torch==2.4.1 \
        torchvision==0.19.1 \
        segmentation-models-pytorch==0.3.3 \
        numpy==1.24.4 \
        pillow \
        opencv-python-headless

# ---------------------------------------------------------
# 5. R 环境
# ---------------------------------------------------------
RUN conda create -n r_env -c conda-forge -y r-base=4.2.0 r-tidyverse r-jsonlite

# ---------------------------------------------------------
# 6. 复制应用文件 & 复制 scripts
# ---------------------------------------------------------
COPY app.py /app/app.py
COPY static/ /app/static/
COPY uploads/ /app/uploads/
COPY scripts/ /app/scripts/

# ---------------------------------------------------------
# 7. 修复脚本权限（核心修复点）
# ---------------------------------------------------------
RUN dos2unix /app/scripts/*.sh || true
RUN chmod +x /app/scripts/*.sh

# ---------------------------------------------------------
# 8. Flask 运行环境（系统 python）
# ---------------------------------------------------------
RUN pip install --no-cache-dir flask werkzeug==2.2.2

# ---------------------------------------------------------
# 9. 服务端口（Render 必须）
# ---------------------------------------------------------
EXPOSE 8000

# ---------------------------------------------------------
# 10. 设置启动命令
# ---------------------------------------------------------
CMD ["python", "app.py"]

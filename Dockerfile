# ---------------------------------------------------------
# 1. Base image：Miniconda（稳定 & Render 最兼容）
# ---------------------------------------------------------
FROM continuumio/miniconda3

# ---------------------------------------------------------
# 2. APT 依赖（轻量、必要）
# ---------------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl wget git nano gcc g++ make build-essential \
        libgl1-mesa-glx libglib2.0-0 dos2unix && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# ---------------------------------------------------------
# 3. 创建 Conda 环境
# ---------------------------------------------------------
RUN conda create -n py37 python=3.7 -y
RUN conda create -n py38 python=3.8 -y
RUN conda create -n r_env -c conda-forge -y r-base=4.2.0 r-tidyverse r-jsonlite

# ---------------------------------------------------------
# 4. 安装 py37 依赖
#   - SimpleITK + pyradiomics 固定版本
#   - 其他从 requirements_py37.txt
# ---------------------------------------------------------
COPY requirements_py37.txt /app/requirements_py37.txt

RUN conda run -n py37 pip install --no-cache-dir SimpleITK==2.2.1 pyradiomics==3.0.1
RUN conda run -n py37 python -m pip install --no-cache-dir -r /app/requirements_py37.txt


# ---------------------------------------------------------
# 5. 安装 py38 依赖
#   - 全部使用 requirements_py38.txt
# ---------------------------------------------------------
COPY requirements_py38.txt /app/requirements_py38.txt
RUN conda run -n py38 python -m pip install --no-cache-dir -r /app/requirements_py38.txt


# ---------------------------------------------------------
# 6. flask（放主环境即可）
# ---------------------------------------------------------
RUN pip install flask

# ---------------------------------------------------------
# 7. 复制项目文件
# ---------------------------------------------------------
COPY static/ /app/static/
COPY models/ /app/models/
COPY scripts/ /app/scripts/
COPY r/ /app/r/
COPY notebooks/ /app/notebooks/
COPY original_notebooks/ /app/original_notebooks/

# 修复脚本权限
RUN chmod +x /app/scripts/*.sh && dos2unix /app/scripts/*.sh

# app.py（最后复制）
COPY app.py /app/app.py

# ---------------------------------------------------------
# 8. 启动服务
# ---------------------------------------------------------
EXPOSE 8000
CMD ["python", "app.py"]



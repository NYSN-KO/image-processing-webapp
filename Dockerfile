# ---------------------------------------------------------
# 基础镜像：micromamba（比 conda 快 10 倍）
# ---------------------------------------------------------
FROM mambaorg/micromamba:latest

WORKDIR /app

# ---------------------------------------------------------
# 复制依赖文件
# ---------------------------------------------------------
COPY requirements_py37.txt /app/
COPY requirements_py38.txt /app/

# ---------------------------------------------------------
# 用 micromamba 创建 3 个环境
# ---------------------------------------------------------
RUN micromamba create -y -n py37 python=3.7 -c conda-forge && \
    micromamba create -y -n py38 python=3.8 -c conda-forge && \
    micromamba create -y -n r_env r-base=4.2.0 r-tidyverse r-jsonlite -c conda-forge && \
    micromamba clean --all --yes

# ---------------------------------------------------------
# 安装 Python 3.7 环境依赖
# ---------------------------------------------------------
RUN micromamba run -n py37 pip install --no-cache-dir SimpleITK==2.2.1 pyradiomics==3.0.1
RUN micromamba run -n py37 pip install --no-cache-dir -r requirements_py37.txt

# ---------------------------------------------------------
# 安装 Python 3.8 环境依赖
# ---------------------------------------------------------
RUN micromamba run -n py38 pip install --no-cache-dir -r requirements_py38.txt

# ---------------------------------------------------------
# 安装 Flask + Notebook 工具（主环境）
# ---------------------------------------------------------
RUN pip install --no-cache-dir flask papermill nbformat nbconvert notebook

# ---------------------------------------------------------
# 复制项目文件
# ---------------------------------------------------------
COPY static/ /app/static/
COPY models/ /app/models/
COPY scripts/ /app/scripts/
COPY r/ /app/r/
COPY notebooks/ /app/notebooks/
COPY original_notebooks/ /app/original_notebooks/

# 脚本权限
RUN chmod +x /app/scripts/*.sh

# app 主程序
COPY app.py /app/app.py

# ---------------------------------------------------------
# 运行 Flask
# ---------------------------------------------------------
EXPOSE 8000
CMD ["python", "app.py"]

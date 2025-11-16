FROM mambaorg/micromamba:1.5.8 AS builder

WORKDIR /app

# 复制依赖文件
COPY requirements_py37.txt .
COPY requirements_py38.txt .

###############################################
# 创建环境：py37
###############################################
RUN micromamba create -n py37 python=3.7 -y && \
    micromamba run -n py37 pip install --no-cache-dir SimpleITK==2.2.1 pyradiomics==3.0.1 && \
    micromamba run -n py37 pip install --no-cache-dir -r requirements_py37.txt

###############################################
# 创建环境：py38
###############################################
RUN micromamba create -n py38 python=3.8 -y && \
    micromamba run -n py38 pip install --no-cache-dir -r requirements_py38.txt

###############################################
# 创建 R 环境（micromamba 完美支持）
###############################################
RUN micromamba create -n r_env -c conda-forge -y r-base=4.2.0 r-tidyverse r-jsonlite

###############################################
# 安装 Flask & Papermill（主环境）
###############################################
RUN pip install flask papermill nbformat nbconvert notebook

###############################################
# 复制项目文件
###############################################
COPY static/ /app/static/
COPY models/ /app/models/
COPY scripts/ /app/scripts/
COPY r/ /app/r/
COPY notebooks/ /app/notebooks/
COPY original_notebooks/ /app/original_notebooks/
COPY app.py /app/app.py

RUN chmod +x /app/scripts/*.sh

EXPOSE 8000

CMD ["python", "app.py"]

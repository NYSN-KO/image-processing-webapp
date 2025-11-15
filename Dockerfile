FROM ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive

# 安装 Python 3.7 和 3.8 以及依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.7 python3.7-venv python3.7-dev \
    python3.8 python3.8-venv python3.8-dev \
    python3-pip build-essential wget curl ca-certificates \
    libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
    libsqlite3-dev tk-dev libffi-dev

# 创建 Python 3.8 venv（用于 OCT_Train_Val_Segmentation）
RUN python3.8 -m venv /opt/py38 && \
    /opt/py38/bin/pip install --upgrade pip && \
    /opt/py38/bin/pip install ipykernel papermill nbconvert nbformat

# 注册 Python 3.8 kernel
RUN /opt/py38/bin/python -m ipykernel install --name python38 --display-name "Python 3.8"

# 创建 Python 3.7 venv（用于 pyradiomic）
RUN python3.7 -m venv /opt/py37 && \
    /opt/py37/bin/pip install --upgrade pip && \
    /opt/py37/bin/pip install ipykernel

# 注册 Python 3.7 kernel
RUN /opt/py37/bin/python -m ipykernel install --name python37 --display-name "Python 3.7"

# 工作目录
WORKDIR /app
COPY . /app

# 安装两个不同 Notebook 所需依赖
RUN if [ -f requirements_py38.txt ]; then /opt/py38/bin/pip install -r requirements_py38.txt; fi
RUN if [ -f requirements_py37.txt ]; then /opt/py37/bin/pip install -r requirements_py37.txt; fi

EXPOSE 8000
CMD ["/opt/py38/bin/python", "app.py"]

# 权限设置与端口暴露
RUN chmod +x /app/scripts/*.sh /app/r/*.R
EXPOSE 8000



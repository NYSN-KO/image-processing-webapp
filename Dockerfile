# 使用 Ubuntu 20.04，支持 Python 3.7 / 3.8 安装
FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# 安装系统依赖和 Python 3.7 / 3.8 / R
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    wget curl git build-essential ca-certificates \
    python3.8 python3.8-venv python3.8-dev \
    python3.7 python3.7-venv python3.7-dev \
    python3-pip r-base && \
    rm -rf /var/lib/apt/lists/*

# 建立两个虚拟环境
RUN python3.8 -m venv /opt/py38 && /opt/py38/bin/pip install --upgrade pip
RUN python3.7 -m venv /opt/py37 && /opt/py37/bin/pip install --upgrade pip

WORKDIR /app
COPY . /app

# 安装两个环境下的依赖
RUN if [ -f requirements_py38.txt ]; then /opt/py38/bin/pip install -r requirements_py38.txt; fi
RUN if [ -f requirements_py37.txt ]; then /opt/py37/bin/pip install -r requirements_py37.txt; fi

RUN chmod +x /app/scripts/*.sh /app/r/*.R

EXPOSE 8000
CMD ["/opt/py38/bin/python", "app.py"]

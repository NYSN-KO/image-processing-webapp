# 使用 Ubuntu 20.04（支持安装多版本 Python）
FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# 安装基础依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    wget curl git build-essential ca-certificates \
    python3-pip r-base \
    libssl-dev zlib1g-dev libbz2-dev \
    libreadline-dev libsqlite3-dev llvm \
    libncurses5-dev libncursesw5-dev \
    libgdbm-dev libdb5.3-dev liblzma-dev \
    tk-dev libpcap-dev libffi-dev liblzma-dev \
    python3-dev && \
    rm -rf /var/lib/apt/lists/*

# 手动编译并安装 Python 3.7
RUN cd /opt && \
    wget https://www.python.org/ftp/python/3.7.9/Python-3.7.9.tgz && \
    tar xvf Python-3.7.9.tgz && \
    cd Python-3.7.9 && \
    ./configure --enable-optimizations && \
    make -j 4 && \
    make altinstall && \
    rm -rf /opt/Python-3.7.9*

# 安装 Python 3.8 和 3.7 虚拟环境
RUN python3.8 -m venv /opt/py38 && /opt/py38/bin/pip install --upgrade pip
RUN python3.7 /opt/python3.7/bin/venv /opt/py37 && /opt/py37/bin/pip install --upgrade pip

WORKDIR /app
COPY . /app

# 安装依赖
RUN if [ -f requirements_py38.txt ]; then /opt/py38/bin/pip install -r requirements_py38.txt; fi
RUN if [ -f requirements_py37.txt ]; then /opt/py37/bin/pip install -r requirements_py37.txt; fi

RUN chmod +x /app/scripts/*.sh /app/r/*.R

EXPOSE 8000
CMD ["/opt/py38/bin/python", "app.py"]

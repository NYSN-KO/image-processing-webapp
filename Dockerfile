# 使用 Ubuntu 20.04
FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# 安装基本工具和 Python 3.8（以及 R）
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    wget curl git build-essential ca-certificates \
    python3-pip r-base \
    libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
    libsqlite3-dev llvm libncurses5-dev libncursesw5-dev \
    libgdbm-dev libdb5.3-dev liblzma-dev tk-dev \
    libffi-dev liblzma-dev make gcc libbz2-dev && \
    rm -rf /var/lib/apt/lists/*

# 安装 pyenv（管理多个 Python 版本）
RUN curl https://pyenv.run | bash

# 配置 pyenv（环境变量）
ENV PATH /root/.pyenv/bin:$PATH
ENV PYENV_ROOT /root/.pyenv
ENV PATH /root/.pyenv/shims:$PATH

# 安装 Python 3.7 和 3.8
RUN pyenv install 3.7.9 && pyenv install 3.8.10
RUN pyenv global 3.8.10 3.7.9

# 创建虚拟环境
RUN pyenv exec python3.8 -m venv /opt/py38 && /opt/py38/bin/pip install --upgrade pip
RUN pyenv exec python3.7 -m venv /opt/py37 && /opt/py37/bin/pip install --upgrade pip

# 设置工作目录
WORKDIR /app
COPY . /app

# 安装依赖
RUN if [ -f requirements_py38.txt ]; then /opt/py38/bin/pip install -r requirements_py38.txt; fi
RUN if [ -f requirements_py37.txt ]; then /opt/py37/bin/pip install -r requirements_py37.txt; fi

# 权限设置与端口暴露
RUN chmod +x /app/scripts/*.sh /app/r/*.R
EXPOSE 8000

# 启动 Flask 服务
CMD ["/opt/py38/bin/python", "app.py"]

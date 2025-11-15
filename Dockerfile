FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# Install system deps + deadsnakes PPA for python3.7
RUN apt-get update && \
    apt-get install -y software-properties-common && \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y \
        wget curl git build-essential ca-certificates \
        python3.7 python3.7-venv python3.7-dev \
        python3.8 python3.8-venv python3.8-dev \
        python3-pip \
        r-base \
        libssl-dev libxml2-dev libcurl4-openssl-dev libjpeg-dev zlib1g-dev && \
    rm -rf /var/lib/apt/lists/*

# Create virtual envs for 3.7 and 3.8
RUN python3.7 -m venv /opt/py37 && \
    python3.8 -m venv /opt/py38

# Upgrade pip inside both envs
RUN /opt/py37/bin/pip install --upgrade pip && \
    /opt/py38/bin/pip install --upgrade pip

# Install python requirements
COPY requirements_py37.txt /tmp/req37.txt
COPY requirements_py38.txt /tmp/req38.txt

RUN /opt/py37/bin/pip install -r /tmp/req37.txt
RUN /opt/py38/bin/pip install -r /tmp/req38.txt

# Install jupyter kernels for papermill
RUN /opt/py38/bin/python -m ipykernel install --name python38 --display-name "Python 3.8"
RUN /opt/py37/bin/python -m ipykernel install --name python37 --display-name "Python 3.7"

# Create working directory
WORKDIR /app

# Copy entire repo
COPY . /app

# Install Flask dependencies (in py38)
RUN /opt/py38/bin/pip install flask

EXPOSE 10000

CMD ["/opt/py38/bin/python", "app.py"]

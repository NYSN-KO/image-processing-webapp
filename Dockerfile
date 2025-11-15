FROM ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update --yes && apt-get install -y --no-install-recommends \
    python3.8 python3.8-venv python3.8-dev python3.7 python3.7-venv python3.7-dev \
    python3-pip build-essential wget curl ca-certificates ffmpeg libsm6 libxext6 libgl1-mesa-glx \
    r-base r-base-core && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY . /app
# create venvs and install requirements
RUN python3.8 -m venv /opt/py38 && /opt/py38/bin/pip install --upgrade pip && /opt/py38/bin/pip install -r requirements_py38.txt
RUN python3.7 -m venv /opt/py37 && /opt/py37/bin/pip install --upgrade pip && /opt/py37/bin/pip install -r requirements_py37.txt
# install papermill kernels
RUN /opt/py38/bin/python -m ipykernel install --user --name python38 --display-name "Python 3.8" && \
    /opt/py37/bin/python -m ipykernel install --user --name python37 --display-name "Python 3.7"
# make scripts executable and R script
RUN chmod +x /app/scripts/*.sh && chmod +x /app/r/*.R
EXPOSE 8000
CMD ["/opt/py38/bin/python", "app.py"]

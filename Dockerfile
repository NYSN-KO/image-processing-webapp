FROM ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /app

# 1) system deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget curl git build-essential ca-certificates software-properties-common \
    python3.7 python3.7-venv python3.7-dev \
    python3.8 python3.8-venv python3.8-dev \
    python3-pip \
    r-base \
    libssl-dev libxml2-dev libcurl4-openssl-dev libjpeg-dev zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# 2) create venvs
RUN python3.7 -m venv /opt/py37 && /opt/py37/bin/python -m pip install --upgrade pip
RUN python3.8 -m venv /opt/py38 && /opt/py38/bin/python -m pip install --upgrade pip

# 3) install papermill, ipykernel, nbformat in both venvs
RUN /opt/py38/bin/pip install papermill nbformat ipykernel jupyter-client
RUN /opt/py37/bin/pip install papermill nbformat ipykernel jupyter-client

# 4) register kernels
RUN /opt/py38/bin/python -m ipykernel install --name python38 --display-name "Python 3.8"
RUN /opt/py37/bin/python -m ipykernel install --name python37 --display-name "Python 3.7"

# 5) install base python libs (extend via requirements files)
COPY requirements_py38.txt /tmp/requirements_py38.txt
COPY requirements_py37.txt /tmp/requirements_py37.txt
RUN if [ -f /tmp/requirements_py38.txt ]; then /opt/py38/bin/pip install -r /tmp/requirements_py38.txt; fi
RUN if [ -f /tmp/requirements_py37.txt ]; then /opt/py37/bin/pip install -r /tmp/requirements_py37.txt; fi

# 6) install R packages your script uses (CRAN)
RUN Rscript -e 'options(repos="https://cloud.r-project.org"); install.packages(c("data.table","dplyr","stringr","pROC","broom","caret","ggplot2","glmnet","jsonlite"))'

# 7) copy project
COPY . /app

# 8) make scripts executable
RUN chmod +x /app/scripts/*.sh || true
RUN chmod +x /app/run_r.sh || true
RUN chmod +x /app/r/*.R || true

# 9) expose port and run
EXPOSE 8000
CMD ["/opt/py38/bin/python", "app.py"]

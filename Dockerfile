# ---------------------------------------------------------
# 1. Base image
# ---------------------------------------------------------
FROM debian:bullseye-slim

# ---------------------------------------------------------
# 2. System dependencies
# ---------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget curl git build-essential \
    python3 python3-pip python3-venv \
    software-properties-common \
    r-base \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------
# 3. Install Python 3.7 (via Deadsnakes PPA)
# ---------------------------------------------------------
RUN apt-get update && \
    apt-get install -y gnupg2 && \
    echo "deb http://ppa.launchpad.net/deadsnakes/ppa/ubuntu focal main" \
        > /etc/apt/sources.list.d/deadsnakes.list && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 6A755776 && \
    apt-get update && \
    apt-get install -y python3.7 python3.7-venv python3.7-distutils && \
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3.7

# ---------------------------------------------------------
# 4. Create two virtual environments
# ---------------------------------------------------------
RUN python3.7 -m venv /env_py37
RUN python3   -m venv /env_py38   # system python3 = 3.8

# ---------------------------------------------------------
# 5. Install dependencies into each environment
# ---------------------------------------------------------
COPY requirements_py37.txt /app/requirements_py37.txt
COPY requirements_py38.txt /app/requirements_py38.txt

RUN /env_py37/bin/pip install --no-cache-dir -r /app/requirements_py37.txt
RUN /env_py38/bin/pip install --no-cache-dir -r /app/requirements_py38.txt

# ---------------------------------------------------------
# 6. Install Flask + papermill + nbconvert (web backend)
# ---------------------------------------------------------
RUN pip3 install flask papermill nbformat nbconvert

# ---------------------------------------------------------
# 7. Copy project
# ---------------------------------------------------------
WORKDIR /app
COPY . /app

# Permissions for shell scripts
RUN chmod +x /app/scripts/*.sh

# ---------------------------------------------------------
# 8. Expose port for Fly.io
# ---------------------------------------------------------
EXPOSE 8080

# ---------------------------------------------------------
# 9. Start Flask backend (using Python 3.8)
# ---------------------------------------------------------
CMD ["/env_py38/bin/python", "app.py"]

FROM debian:bullseye-slim

# ------------------------------------------------------
# 1. System dependencies
# ------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget curl git build-essential \
    libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
    libsqlite3-dev libncursesw5-dev libgdbm-dev libnss3-dev liblzma-dev \
    libffi-dev uuid-dev \
    python3 python3-pip python3-venv \
    r-base \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------
# 2. Install pyenv (to install Python 3.7 from source)
# ------------------------------------------------------
ENV PYENV_ROOT="/root/.pyenv"
ENV PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"

RUN git clone https://github.com/pyenv/pyenv.git ~/.pyenv

# ------------------------------------------------------
# 3. Build Python 3.7 using pyenv
# ------------------------------------------------------
RUN pyenv install 3.7.17
RUN pyenv global 3.7.17

# Now python3.7 is available at /root/.pyenv/shims/python3.7

# ------------------------------------------------------
# 4. Create venvs for py37 and py38
# ------------------------------------------------------
RUN /root/.pyenv/shims/python3.7 -m venv /env_py37
RUN python3 -m venv /env_py38

# ------------------------------------------------------
# 5. Install dependencies
# ------------------------------------------------------
COPY requirements_py37.txt /app/requirements_py37.txt
COPY requirements_py38.txt /app/requirements_py38.txt

RUN /env_py37/bin/pip install --no-cache-dir -r /app/requirements_py37.txt
RUN /env_py38/bin/pip install --no-cache-dir -r /app/requirements_py38.txt

# Flask backend
RUN pip3 install flask papermill nbformat nbconvert

# ------------------------------------------------------
# 6. Copy project files
# ------------------------------------------------------
WORKDIR /app
COPY . /app
COPY SimpleITK.py /app/SimpleITK.py
RUN chmod +x /app/scripts/*.sh

# ------------------------------------------------------
# 7. Expose port and start app
# ------------------------------------------------------
EXPOSE 8080
CMD ["/env_py38/bin/python", "app.py"]


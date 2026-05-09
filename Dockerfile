# Install npm packages
FROM node:20-alpine AS npm

WORKDIR /code

COPY ./static/package*.json /code/static/

RUN cd /code/static && npm ci


# Main image (ARM64)
FROM arm64v8/python:3.12-slim-bookworm

ARG UV_VERSION="0.10.12"

# Keeps Python from generating .pyc files in the container
ENV PYTHONDONTWRITEBYTECODE=1

# Turns off buffering for easier container logging
ENV PYTHONUNBUFFERED=1

WORKDIR /code

# Copy dependency files
COPY pyproject.toml uv.lock .python-version ./

# Install deps
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
        netcat-traditional \
        gcc \
        python3-dev \
        gnupg \
        git \
        libre2-dev \
        build-essential \
        pkg-config \
        cmake \
        ninja-build \
        bash \
        clang \
    && curl -sSL \
        "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-aarch64-unknown-linux-gnu.tar.gz" \
        > uv.tar.gz \
    && tar xf uv.tar.gz -C /tmp/ \
    && mv /tmp/uv-aarch64-unknown-linux-gnu/uv /usr/bin/uv \
    && mv /tmp/uv-aarch64-unknown-linux-gnu/uvx /usr/bin/uvx \
    && rm -rf /tmp/uv* \
    && rm -f uv.tar.gz \
    && uv python install `cat .python-version` \
    && export CMAKE_POLICY_VERSION_MINIMUM=3.5 \
    && uv sync --locked --no-dev \
    && apt-get purge -y \
        curl \
        build-essential \
        pkg-config \
        cmake \
        ninja-build \
        python3-dev \
        clang \
        gcc \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy code
COPY . .

# copy npm packages
COPY --from=npm /code /code

ENV PATH="/code/.venv/bin:$PATH"

EXPOSE 7777

# gunicorn wsgi:app -b 0.0.0.0:7777 -w 2 --timeout 15 --log-level DEBUG
CMD ["gunicorn","wsgi:app","-b","0.0.0.0:7777","-w","2","--timeout","15"]

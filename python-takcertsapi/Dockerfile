# syntax=docker/dockerfile:1.1.7-experimental
#############################################
# Tox testsuite for multiple python version #
#############################################
FROM advian/tox-base:debian-bullseye as tox
ARG PYTHON_VERSIONS="3.10 3.9 3.8"
ARG POETRY_VERSION="1.2.2"
RUN export RESOLVED_VERSIONS=`pyenv_resolve $PYTHON_VERSIONS` \
    && echo RESOLVED_VERSIONS=$RESOLVED_VERSIONS \
    && for pyver in $RESOLVED_VERSIONS; do pyenv install -s $pyver; done \
    && pyenv global $RESOLVED_VERSIONS \
    && poetry self update $POETRY_VERSION || pip install -U poetry==$POETRY_VERSION \
    && pip install -U tox \
    && apt-get update && apt-get install -y \
        git \
    && rm -rf /var/lib/apt/lists/* \
    && true

######################
# Base builder image #
######################
FROM python:3.8-bullseye as builder_base

ENV \
  # locale
  LC_ALL=C.UTF-8 \
  # python:
  PYTHONFAULTHANDLER=1 \
  PYTHONUNBUFFERED=1 \
  PYTHONHASHSEED=random \
  # pip:
  PIP_NO_CACHE_DIR=off \
  PIP_DISABLE_PIP_VERSION_CHECK=on \
  PIP_DEFAULT_TIMEOUT=100 \
  # poetry:
  POETRY_VERSION=1.2.2


RUN apt-get update && apt-get install -y \
        curl \
        git \
        bash \
        build-essential \
        libffi-dev \
        libssl-dev \
        libzmq3-dev \
        tini \
        openssh-client \
        cargo \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* \
    # githublab ssh
    && mkdir -p -m 0700 ~/.ssh && ssh-keyscan gitlab.com github.com | sort > ~/.ssh/known_hosts \
    # Installing `poetry` package manager:
    && curl -sSL https://install.python-poetry.org | python3 - \
    && echo 'export PATH="/root/.local/bin:$PATH"' >>/root/.profile \
    && export PATH="/root/.local/bin:$PATH" \
    && true

SHELL ["/bin/bash", "-lc"]


# Copy only requirements, to cache them in docker layer:
WORKDIR /pysetup
COPY ./poetry.lock ./pyproject.toml /pysetup/
# Install basic requirements (utilizing an internal docker wheelhouse if available)
RUN --mount=type=ssh pip3 install wheel virtualenv \
    && poetry export -f requirements.txt --without-hashes -o /tmp/requirements.txt \
    && pip3 wheel --wheel-dir=/tmp/wheelhouse -r /tmp/requirements.txt \
    && virtualenv /.venv && source /.venv/bin/activate && echo 'source /.venv/bin/activate' >>/root/.profile \
    && pip3 install --no-deps --find-links=/tmp/wheelhouse/ /tmp/wheelhouse/*.whl \
    && true


####################################
# Base stage for production builds #
####################################
FROM builder_base as production_build
# Copy entrypoint script
COPY ./docker/entrypoint.sh /docker-entrypoint.sh
# Only files needed by production setup
COPY ./poetry.lock ./pyproject.toml ./README.rst ./src /app/
WORKDIR /app
# Build the wheel package with poetry and add it to the wheelhouse
RUN --mount=type=ssh source /.venv/bin/activate \
    && poetry build -f wheel --no-interaction --no-ansi \
    && cp dist/*.whl /tmp/wheelhouse \
    && chmod a+x /docker-entrypoint.sh \
    && true


#########################
# Main production build #
#########################
FROM python:3.8-slim-bullseye as production
COPY --from=production_build /tmp/wheelhouse /tmp/wheelhouse
COPY --from=production_build /docker-entrypoint.sh /docker-entrypoint.sh
WORKDIR /app
# Install system level deps for running the package (not devel versions for building wheels)
# and install the wheels we built in the previous step. generate default config
RUN --mount=type=ssh apt-get update && apt-get install -y \
        bash \
        libffi7 \
        libzmq5 \
        tini \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* \
    && chmod a+x /docker-entrypoint.sh \
    && WHEELFILE=`echo /tmp/wheelhouse/takcertsapi-*.whl` \
    && pip3 install --find-links=/tmp/wheelhouse/ "$WHEELFILE"[all] \
    && rm -rf /tmp/wheelhouse/ \
    # Do whatever else you need to
    && true
ENTRYPOINT ["/usr/bin/tini", "--", "/docker-entrypoint.sh"]


#####################################
# Base stage for development builds #
#####################################
FROM builder_base as devel_build
# Install deps
WORKDIR /pysetup
RUN --mount=type=ssh source /.venv/bin/activate \
    && poetry install --no-interaction --no-ansi \
    && true


#0############
# Run tests #
#############
FROM devel_build as test
COPY . /app
WORKDIR /app
ENTRYPOINT ["/usr/bin/tini", "--", "docker/entrypoint-test.sh"]
# Re run install to get the service itself installed
RUN --mount=type=ssh source /.venv/bin/activate \
    && poetry install --no-interaction --no-ansi \
    && docker/pre_commit_init.sh \
    && true


###########
# Hacking #
###########
FROM devel_build as devel_shell
# Copy everything to the image
COPY . /app
WORKDIR /app
RUN apt-get update && apt-get install -y zsh \
    && sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    && pip3 install git-up \
    && true
ENTRYPOINT ["/bin/zsh", "-l"]

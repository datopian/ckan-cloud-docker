# Based on CKAN 2.8 Dockerfile with minor modifications for deployment on multi-tenant CKAN cluster and support for CKAN 2.10+ and Python 3
FROM debian:trixie

ARG EXTRA_PACKAGES
ARG PIP_INDEX_URL
ENV PIP_INDEX_URL=$PIP_INDEX_URL
ARG GITHUB_URL
ENV GITHUB_URL=$GITHUB_URL
ENV APP_DIR=/srv/app
ENV CKAN_CONFIG_PATH=/etc/ckan

RUN apt update
RUN apt install -y locales

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Python 3.9 install adapted from https://techkamar.medium.com/how-to-deploy-specific-version-of-python-using-docker-96d387c16779
# Set the working directory inside the container
WORKDIR ${APP_DIR}

# Copy the requirements file to the working directory
RUN mkdir /opt/python3.9

# To avoid .pyc files and save space
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# Install all dependecnies you need to compile Python3.9
RUN apt update
RUN apt install -y \
    wget \
    libffi-dev \
    gcc \
    build-essential \
    curl \
    tcl-dev \
    tk-dev \
    uuid-dev \
    lzma-dev \
    liblzma-dev \
    libssl-dev \
    libsqlite3-dev

# Download, build, and install Python 3.9
RUN wget https://www.python.org/ftp/python/3.9.18/Python-3.9.18.tgz && \
    tar -zxvf Python-3.9.18.tgz && \
    cd Python-3.9.18 && ./configure --prefix=/opt/python3.9 && make && make install && \
    ln -s /opt/python3.9/bin/python3.9 /usr/bin/python3.9

# Verify Python installation
RUN /usr/bin/python3.9 --version

WORKDIR /

# Python 3.9 install --------- END

# Install required system packages
RUN apt-get -q -y update \
    && DEBIAN_FRONTEND=noninteractive apt-get -q -y upgrade \
    && apt-get -q -y install \
        libpq-dev \
        libxml2-dev \
        libxslt-dev \
        libgeos-dev \
        libssl-dev \
        libffi-dev \
        postgresql-client \
        git-core \
        vim \
        redis-tools \
        gettext \
        libmagic-dev \
        musl-dev \
        ${EXTRA_PACKAGES} \
    && apt-get -q clean \
    && rm -rf /var/lib/apt/lists/*

# Define environment variables
ENV CKAN_HOME /usr/lib/ckan
ENV CKAN_VENV $CKAN_HOME/venv
ENV CKAN_CONFIG /etc/ckan
ENV CKAN_STORAGE_PATH=/var/lib/ckan
ENV CKAN_LOGS_PATH=/var/log/ckan

# Create ckan user
RUN useradd -r -u 900 -m -c "ckan account" -d $CKAN_HOME -s /bin/false ckan

# Setup virtual environment for CKAN
RUN mkdir -p $CKAN_VENV $CKAN_CONFIG $CKAN_STORAGE_PATH $CKAN_LOGS_PATH && \
    /usr/bin/python3.9 -m venv $CKAN_VENV && \
    ln -s $CKAN_VENV/bin/pip /usr/local/bin/ckan-pip &&\
    ln -s $CKAN_VENV/bin/ckan /usr/local/bin/ckan

RUN ckan-pip install --upgrade pip &&\
    ckan-pip install --upgrade setuptools &&\
    ckan-pip install --upgrade wheel

RUN ckan-pip install supervisor && \
    ckan-pip install uwsgi==2.0.19.1 && \
    ckan-pip install gevent==24.2.1

RUN apt-get update && apt-get install -y \
    uwsgi-plugins-all \
    uwsgi-plugin-python3

# Setup CKAN
RUN ckan-pip install --index-url ${PIP_INDEX_URL:-https://pypi.org/simple/} -U pip &&\
    chown -R ckan:ckan $CKAN_HOME $CKAN_VENV $CKAN_CONFIG $CKAN_STORAGE_PATH $CKAN_LOGS_PATH

USER ckan

ARG CKAN_BRANCH
ARG CKAN_REPO

RUN CKAN_BRANCH="${CKAN_BRANCH:-ckan-2.10.4}" && CKAN_REPO="${CKAN_REPO:-ckan/ckan}" &&\
    mkdir -p $CKAN_VENV/src &&\
    wget --no-verbose -O $CKAN_VENV/src/${CKAN_BRANCH}.tar.gz https://github.com/${CKAN_REPO}/archive/${CKAN_BRANCH}.tar.gz &&\
    cd $CKAN_VENV/src && tar -xzf ${CKAN_BRANCH}.tar.gz && mv ckan-${CKAN_BRANCH} ckan &&\
    rm $CKAN_VENV/src/${CKAN_BRANCH}.tar.gz

ARG PRE_INSTALL
RUN eval "${PRE_INSTALL}"

RUN touch $CKAN_VENV/src/ckan/requirement-setuptools.txt && ckan-pip install --index-url ${PIP_INDEX_URL:-https://pypi.org/simple/} --upgrade --no-cache-dir -r $CKAN_VENV/src/ckan/requirement-setuptools.txt
RUN touch $CKAN_VENV/src/ckan/requirements.txt && ckan-pip install --index-url ${PIP_INDEX_URL:-https://pypi.org/simple/} --upgrade --no-cache-dir -r $CKAN_VENV/src/ckan/requirements.txt

RUN ckan-pip install --index-url ${PIP_INDEX_URL:-https://pypi.org/simple/} -e $CKAN_VENV/src/ckan/

COPY requirements.txt /tmp/

RUN ckan-pip install --index-url ${PIP_INDEX_URL:-https://pypi.org/simple/} -r /tmp/requirements.txt && \
    ckan-pip install --index-url ${PIP_INDEX_URL:-https://pypi.org/simple/} -U requests[security]

COPY post_install_functions.sh /post_install_functions.sh

ARG POST_INSTALL
RUN . /post_install_functions.sh && eval "${POST_INSTALL}"

COPY entrypoint.sh /ckan-entrypoint.sh
COPY templater.sh /templater.sh

ARG POST_DOCKER_BUILD
RUN . /post_install_functions.sh && eval "${POST_DOCKER_BUILD}"

ARG CKAN_INIT
RUN echo "${CKAN_INIT}" | sed s@CKAN_CONFIG@${CKAN_CONFIG}@g > ${CKAN_CONFIG}/ckan_extra_init.sh

USER root

# Extra files in the filesystem
ARG EXTRA_FILESYSTEM
COPY ${EXTRA_FILESYSTEM} /

# Initialization that should be done as root
ARG ROOT_INIT
RUN eval "${ROOT_INIT}"
RUN . /post_install_functions.sh && patch_ckan

ADD https://raw.githubusercontent.com/ckan/ckan/${CKAN_BRANCH}/wsgi.py ${CKAN_VENV}/wsgi.py
RUN chmod 644 ${CKAN_VENV}/wsgi.py

RUN mkdir /etc/supervisord.d
COPY setup/supervisord.conf /etc

USER ckan

ENTRYPOINT ["/ckan-entrypoint.sh"]

EXPOSE 5000

ENV GUNICORN_WORKERS=4
ENV GUNICORN_TIMEOUT=200

WORKDIR /usr/lib/ckan

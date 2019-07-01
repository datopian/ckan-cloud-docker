# Based on CKAN 2.8 Dockerfile with minor modifications for deployment on multi-tenant CKAN cluster

FROM debian:jessie

ARG EXTRA_PACKAGES

# Install required system packages
RUN printf "deb http://archive.debian.org/debian/ jessie main\ndeb-src http://archive.debian.org/debian/ jessie main\ndeb http://security.debian.org jessie/updates main\ndeb-src http://security.debian.org jessie/updates main" > /etc/apt/sources.list \
    && apt-get -q -y update \
    && DEBIAN_FRONTEND=noninteractive apt-get -q -y upgrade \
    && apt-get -q -y install \
        python-dev \
        python-pip \
        python-virtualenv \
        python-wheel \
        libpq-dev \
        libxml2-dev \
        libxslt-dev \
        libgeos-dev \
        libssl-dev \
        libffi-dev \
        postgresql-client \
        build-essential \
        git-core \
        vim \
        wget \
        redis-tools \
        gettext \
        ${EXTRA_PACKAGES} \
    && apt-get -q clean \
    && rm -rf /var/lib/apt/lists/*


# Define environment variables
ENV CKAN_HOME /usr/lib/ckan
ENV CKAN_VENV $CKAN_HOME/venv
ENV CKAN_CONFIG /etc/ckan
ENV CKAN_STORAGE_PATH=/var/lib/ckan
ENV CKAN_LOGS_PATH=/var/log/ckan
ENV PIP_INDEX_URL="${PIP_INDEX_URL:-https://pypi.org/simple/}"

# Create ckan user
RUN useradd -r -u 900 -m -c "ckan account" -d $CKAN_HOME -s /bin/false ckan

# Setup virtual environment for CKAN
RUN mkdir -p $CKAN_VENV $CKAN_CONFIG $CKAN_STORAGE_PATH $CKAN_LOGS_PATH && \
    virtualenv $CKAN_VENV && \
    ln -s $CKAN_VENV/bin/pip /usr/local/bin/ckan-pip &&\
    ln -s $CKAN_VENV/bin/paster /usr/local/bin/ckan-paster

# Setup CKAN
RUN ckan-pip install -U pip &&\
    chown -R ckan:ckan $CKAN_HOME $CKAN_VENV $CKAN_CONFIG $CKAN_STORAGE_PATH $CKAN_LOGS_PATH

USER ckan

ARG CKAN_BRANCH
ARG CKAN_REPO

RUN CKAN_BRANCH="${CKAN_BRANCH:-ckan-2.8.1}" && CKAN_REPO="${CKAN_REPO:-ckan/ckan}" &&\
    mkdir -p $CKAN_VENV/src &&\
    wget --no-verbose -O $CKAN_VENV/src/${CKAN_BRANCH}.tar.gz https://github.com/${CKAN_REPO}/archive/${CKAN_BRANCH}.tar.gz &&\
    cd $CKAN_VENV/src && tar -xzf ${CKAN_BRANCH}.tar.gz && mv ckan-${CKAN_BRANCH} ckan &&\
    rm $CKAN_VENV/src/${CKAN_BRANCH}.tar.gz

RUN ckan-pip install --upgrade --no-cache-dir -r $CKAN_VENV/src/ckan/requirement-setuptools.txt
RUN ckan-pip install --upgrade --no-cache-dir -r $CKAN_VENV/src/ckan/requirements.txt

RUN ckan-pip install -e $CKAN_VENV/src/ckan/

COPY requirements.txt /tmp/
RUN ckan-pip install -r /tmp/requirements.txt &&\
    ckan-pip install -U requests[security]

COPY post_install_functions.sh /post_install_functions.sh

ARG POST_INSTALL
RUN . /post_install_functions.sh &&  eval "${POST_INSTALL}"

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

USER ckan

ENTRYPOINT ["/ckan-entrypoint.sh"]

EXPOSE 5000

ENV GUNICORN_WORKERS=2

WORKDIR /usr/lib/ckan

# Based on CKAN 2.8 Dockerfile with minor modifications for deployment on multi-tenant CKAN cluster

FROM debian:jessie

# Install required system packages
RUN apt-get -q -y update \
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
    && apt-get -q clean \
    && rm -rf /var/lib/apt/lists/*

# Define environment variables
ENV CKAN_HOME /usr/lib/ckan
ENV CKAN_VENV $CKAN_HOME/venv
ENV CKAN_CONFIG /etc/ckan
ENV CKAN_STORAGE_PATH=/var/lib/ckan

# Create ckan user
RUN useradd -r -u 900 -m -c "ckan account" -d $CKAN_HOME -s /bin/false ckan

# Setup virtual environment for CKAN
RUN mkdir -p $CKAN_VENV $CKAN_CONFIG $CKAN_STORAGE_PATH && \
    virtualenv $CKAN_VENV && \
    ln -s $CKAN_VENV/bin/pip /usr/local/bin/ckan-pip &&\
    ln -s $CKAN_VENV/bin/paster /usr/local/bin/ckan-paster

# Setup CKAN
RUN ckan-pip install -U pip &&\
    chown -R ckan:ckan $CKAN_HOME $CKAN_VENV $CKAN_CONFIG $CKAN_STORAGE_PATH

USER ckan

ARG CKAN_BRANCH
ARG CKAN_REPO

RUN CKAN_BRANCH="${CKAN_BRANCH:-ckan-2.8.1}" && CKAN_REPO="${CKAN_REPO:-ckan/ckan}" &&\
    mkdir -p $CKAN_VENV/src &&\
    wget -O $CKAN_VENV/src/${CKAN_BRANCH}.tar.gz https://github.com/${CKAN_REPO}/archive/${CKAN_BRANCH}.tar.gz &&\
    cd $CKAN_VENV/src && tar -xzvf ${CKAN_BRANCH}.tar.gz && mv ckan-${CKAN_BRANCH} ckan &&\
    rm $CKAN_VENV/src/${CKAN_BRANCH}.tar.gz

RUN ckan-pip install --upgrade --no-cache-dir -r $CKAN_VENV/src/ckan/requirement-setuptools.txt
RUN ckan-pip install --upgrade --no-cache-dir -r $CKAN_VENV/src/ckan/requirements.txt

RUN ckan-pip install -e $CKAN_VENV/src/ckan/

COPY requirements.txt /tmp/
RUN ckan-pip install -r /tmp/requirements.txt &&\
    ckan-pip install -U requests[security]

COPY post_install_functions.sh /post_install_functions.sh

ARG POST_INSTALL
RUN . /post_install_functions.sh && eval "${POST_INSTALL}"

COPY entrypoint.sh /ckan-entrypoint.sh
COPY templater.sh /templater.sh

ARG POST_DOCKER_BUILD
RUN . /post_install_functions.sh && eval "${POST_DOCKER_BUILD}"

ENTRYPOINT ["/ckan-entrypoint.sh"]

EXPOSE 5000

ENV GUNICORN_WORKERS=2

WORKDIR /usr/lib/ckan

FROM viderum/base:0.4

MAINTAINER Keitaro Inc <info@keitaro.info>

ENV APP_DIR=/srv/app
ENV GIT_BRANCH master
ENV GIT_URL https://github.com/ckan/datapusher.git
ENV JOB_CONFIG ${APP_DIR}/datapusher_settings.py

WORKDIR ${APP_DIR}


ARG APK_REPOSITORY
ARG PIP_INDEX_URL
ENV PIP_INDEX_URL=$PIP_INDEX_URL

RUN apk add --no-cache python \
    py-pip \
    py-gunicorn \
    libffi-dev \
    libressl-dev \
    libxslt --update-cache --repository ${APK_REPOSITORY} --allow-untrusted && \
    pip install --upgrade pip && \
    # Temporary packages to build CKAN requirements
    apk add --no-cache --virtual .build-deps \
    gcc \
    git \
    musl-dev \
    python-dev \
    libxml2-dev \
    libxslt-dev --update-cache --repository ${APK_REPOSITORY} --allow-untrusted && \
    # Fetch datapusher and install
    mkdir ${APP_DIR}/src && cd ${APP_DIR}/src && \
    git clone -b ${GIT_BRANCH} --depth=1 --single-branch ${GIT_URL} && \
    cd datapusher && \
    # pin xlrd version for xlsx support
    pip install xlrd==1.2.0 && \
    python setup.py install && \
    pip install --index-url ${PIP_INDEX_URL:-https://pypi.org/simple/} --no-cache-dir -r requirements.txt && \
    # Remove temporary packages and files
    apk del .build-deps && \
    rm -rf ${APP_DIR}/src

COPY setup ${APP_DIR}

EXPOSE 8800

CMD ["gunicorn", "--bind=0.0.0.0:8800", "--log-file=-", "wsgi"]

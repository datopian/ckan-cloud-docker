# CKAN Cloud Docker

[![Build Status](https://travis-ci.org/ViderumGlobal/ckan-cloud-docker.svg?branch=master)](https://travis-ci.org/ViderumGlobal/ckan-cloud-docker)

Contains Docker imgages for the different components of CKAN Cloud and a Docker compose environment for development and testing.

Available components:

* **cca-operator**: Kubernetes server-side component that manages the multi-tenant CKAN instances. see the [README](cca-operator/README.md) for more details.
* **ckan**: The CKAN app
* **db**: PostgreSQL database and management scripts
* **nginx**: Reverse proxy for the CKAN app
* **solr**: Solr search engine
* **jenkins**: Automation service
* **provisioning-api**: [ckan-cloud-provisioning-api](https://github.com/ViderumGlobal/ckan-cloud-provisioning-api)
* **traefik**: Reverse proxy, SSL handler and load balancer


## Install

Install Docker for [Windows](https://store.docker.com/editions/community/docker-ce-desktop-windows),
[Mac](https://store.docker.com/editions/community/docker-ce-desktop-mac) or [Linux](https://docs.docker.com/install/).

[Install Docker Compose](https://docs.docker.com/compose/install/)


## Generate or update files with secrets
Run and follow all steps:
```
./create_secrets.py
```

## Running a CKAN instance using the docker-compose environment

(optional) Clear any existing compose environment to ensure a fresh start

```
docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.datagov-theme.yaml down -v
```

Pull the latest images

```
docker-compose pull
```

Start the Docker compose environment

```
docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.datagov-theme.yaml up -d nginx
```

Add a hosts entry mapping domain `nginx` to `127.0.0.1`:

```
127.0.0.1 nginx
```

Wait a few seconds until CKAN api responds successfully:

```
curl http://nginx:8080/api/3
```

Create a CKAN admin user

```
docker-compose exec ckan ckan-paster --plugin=ckan \
    sysadmin add -c /etc/ckan/production.ini admin password=12345678 email=admin@localhost
```

Login to CKAN at http://nginx:8080 with username `admin` and password `12345678`

To start the jobs server for uploading to the datastore DB:

```
docker-compose up -d jobs
```


## Making modifications to the docker images / configuration

Edit any file in this repository

(Optional) depending on the changes you made, you might need to destroy the current environment

```
docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.datagov-theme.yaml down -v
```

(if you want to keep your volumes, for example if you populated the database with data you want
to keep, you need to drop the `-v` part from the command)

Build the docker images

```
docker-compose build | grep "Successfully tagged"
```

Start the environment

```
docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.datagov-theme.yaml up -d nginx
```


## Create a predefined docker-compose override configuration

This allows to test different CKAN configurations and extension combinations

Duplicate the CKAN default configuration:

```
cp docker-compose/ckan-conf-templates/production.ini.template \
   docker-compose/ckan-conf-templates/my-ckan-production.ini.template
```

Edit the duplicated file and modify the settings, e.g. add the extensions to the `plugins` configuration and any additional required extension configurations.

Create a docker-compose override file e.g. `.docker-compose.my-ckan.yaml`:

```
version: '3.2'

services:
  jobs:
    build:
      context: ckan
      args:
        # install extensions / dependencies
        POST_INSTALL: |
          install_standard_ckan_extension_github -r ckan/ckanext-spatial &&\
          install_standard_ckan_extension_github -r ckan/ckanext-harvest &&\
          install_standard_ckan_extension_github -r GSA/ckanext-geodatagov &&\
          install_standard_ckan_extension_github -r GSA/ckanext-datagovtheme
        # other initialization
        POST_DOCKER_BUILD: |
          mkdir -p /var/tmp/ckan/dynamic_menu
    environment:
    # used to load the modified CKAN configuration
    - CKAN_CONFIG_TEMPLATE_PREFIX=my-ckan-
  ckan:
    build:
      context: ckan
      args:
        # install extensions / dependencies
        POST_INSTALL: |
          install_standard_ckan_extension_github -r ckan/ckanext-spatial &&\
          install_standard_ckan_extension_github -r ckan/ckanext-harvest &&\
          install_standard_ckan_extension_github -r GSA/ckanext-geodatagov &&\
          install_standard_ckan_extension_github -r GSA/ckanext-datagovtheme
        # other initialization
        POST_DOCKER_BUILD: |
          mkdir -p /var/tmp/ckan/dynamic_menu
    environment:
    # used to load the modified CKAN configuration
    - CKAN_CONFIG_TEMPLATE_PREFIX=my-ckan-
```

Start the docker-compose environment with the modified config:

```
docker-compose -f docker-compose.yaml -f .docker-compose.my-ckan.yaml up -d --build nginx
```

You can persist the modified configurations in Git for reference and documentation.

For example, to start the datagov-theme configuration:

```
docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.datagov-theme.yaml up -d --build nginx
```

## External database server

To use another database server, you will need to provide a `SQLACHEMY_URL` value by hand, by adding it
to `docker-compose/ckan-secrets.sh` first.

After specifying the address of the new server, you need to start the CKAN instance, this time without adding a db layer.
For example, to start a custom configuration without starting up the database:

```
docker-compose -f docker-compose.yaml -f .docker-compose.custom-theme.yaml up -d --build nginx
```


## Running cca-operator

see [cca-operator README](cca-operator/README.md)


## Run the Jenkins server

```
docker-compose up -d jenkins
```

Login at http://localhost:8089


## Running the cloud provisioning API

Start the cca-operator server (see [cca-operator README](cca-operator/README.md))

Start the cloud provisioning API server with the required keys

```
export PRIVATE_SSH_KEY="$(cat docker-compose/cca-operator/id_rsa | while read i; do echo "${i}"; done)"
export PRIVATE_KEY="$(cat docker-compose/provisioning-api/private.pem | while read i; do echo "${i}"; done)"
export PUBLIC_KEY="$(cat docker-compose/provisioning-api/public.pem | while read i; do echo "${i}"; done)"

docker-compose up -d --build provisioning-api
```

## Testing the centralized DB

Create a bash alias to run docker-compose with the centralized configuration

```
alias docker-compose="`which docker-compose` -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose-centralized.yaml"
```

Start a clean environment with only the db and solr cloud -

```
docker-compose down -v
docker-compose up -d db solr
```

Set the instance id which is used for database names and the solr core name

```
INSTANCE_ID=test1
```

Create the dbs

```
docker-compose run --rm cca-operator -c "source functions.sh; PGPASSWORD=123456 create_db db postgres ${INSTANCE_ID} 654321" &&\
docker-compose run --rm cca-operator -c "source functions.sh; PGPASSWORD=123456 create_datastore_db db postgres ${INSTANCE_ID} ${INSTANCE_ID}-datastore 654321 ${INSTANCE_ID}-datastore-readonly 654321"
```

Create the solrcloud collection

```
docker-compose exec solr bin/solr create_collection -c ${INSTANCE_ID} -d ckan_default -n ckan_default
```

Start ckan

```
docker-compose up -d --force-recreate jobs
```

by default it uses `test1` as the INSTANCE_ID, to modify, override the ckan secrets.sh

You might need to reload the solr collection after recreate:

```
curl "http://localhost:8983/solr/admin/collections?action=RELOAD&name=${INSTANCE_ID}&wt=json"
```

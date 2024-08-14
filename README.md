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

If you're setting up a local environment for development and testing, you can leave all of the secret values as is. Just press enter when prompted for a value.

## Running locally for development and testing

If you want to run this locally and don't want to deploy it anywhere, you must make a few changes before you can start the environment. Once you've gone through the steps below and started the environment, you can access CKAN at http://ckan:5000 (when creating secrets, don't change the default site URL).

**Note**: The "Install" and "Generate or update files with secrets" sections above are still required before proceeding with a local setup. After making the changes below, you can continue with the "Running a CKAN instance using the docker-compose environment" section.

### Use traefik.dev.toml

By default, `traefik` will attempt to generate a certificate and use https. This will cause issues with the local development environment. To fix this, you can use the `traefik.dev.toml` by updating the `proxy` service in `docker-compose.yaml` to use the `traefik.dev.toml` file. The dev version doesn't generate a certificate and uses http instead of https.

```
  proxy:
    image: traefik:1.7.2-alpine
    restart: always
    volumes:
      - ./traefik/traefik.dev.toml:/traefik.toml # <-- Replace ./traefik/traefik.toml with ./traefik/traefik.dev.toml as shown here
      - ./traefik/acme.json:/acme.json
    networks:
    - ckan-multi
```

### Expose port 5000 for CKAN

In your project specific `docker-compose` file, you must expose port 5000 for CKAN. Otherwise, CKAN will not be accessible from the host machine. For example, if you want to run `.docker-compose.vital-strategies-theme.yaml` locally, you would add the ports section as shown below:

```
  ckan:
    depends_on:
      - datapusher
    links:
      - datapusher
    image: viderum/ckan-cloud-docker:ckan-latest-vital-strategies-theme
    build:
      context: ckan
      args:
        CKAN_BRANCH: ckan-2.7.3
        EXTRA_PACKAGES: cron
        EXTRA_FILESYSTEM: "./overrides/vital-strategies/filesystem/"
        PRE_INSTALL: "sed  -i -e 's/psycopg2==2.4.5/psycopg2==2.7.7/g' ~/venv/src/ckan/requirements.txt"
        POST_INSTALL: |
          install_standard_ckan_extension_github -r ViderumGlobal/ckanext-querytool -b v2.1.2 &&\
          install_standard_ckan_extension_github -r ckan/ckanext-geoview && \
          install_standard_ckan_extension_github -r okfn/ckanext-sentry && \
          install_standard_ckan_extension_github -r ckan/ckanext-googleanalytics -b v2.0.2 && \
          install_standard_ckan_extension_github -r datopian/ckanext-s3filestore -b fix-null-content-type && \
          cd ~/venv/src/ckanext-querytool && ~/venv/bin/python setup.py compile_catalog -l en -f && \
          cd ~/venv/src/ckanext-querytool && ~/venv/bin/python setup.py compile_catalog -l es -f && \
          cd ~/venv/src/ckanext-querytool && ~/venv/bin/python setup.py compile_catalog -l fr -f && \
          cd ~/venv/src/ckanext-querytool && ~/venv/bin/python setup.py compile_catalog -l km -f && \
          cd ~/venv/src/ckanext-querytool && ~/venv/bin/python setup.py compile_catalog -l pt_BR -f && \
          cd ~/venv/src/ckanext-querytool && ~/venv/bin/python setup.py compile_catalog -l zh_CN -f
    environment:
      - CKAN_CONFIG_TEMPLATE_PREFIX=vital-strategies-theme-
    ports: # <-- Add this section to expose port 5000
    - 5000:5000
```

### Remove unused plugins from CKAN

Before building and starting the environment, make sure you only have the required plugins enabled. If you're using a pre-defined project template for local testing, you might not need some of the included extensions, such as `ckanext-googleanalytics` or `ckanext-sentry`. For example, if you want to use the `vital-strategies` project template, you should remove the following plugins from the `.ini` file (found in `docker-compose/ckan-conf-templates/vital-strategies-theme-ckan.ini`) to avoid issues (unless you want to properly configure them):

```
ckan.plugins = image_view
   text_view
   recline_view
   datastore
   datapusher
   resource_proxy
   geojson_view
   querytool
   stats
   sentry # <-- Remove this line
   s3filestore # <-- Remove this line
   googleanalytics # <-- Remove this line
```

### Hosts file entries

When using this environment locally, you must add the following entries to your hosts file (`nginx` is mentioned in the next section, but `ckan` is specific to the development and testing setup):

```
127.0.0.1  nginx
127.0.0.1  ckan
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
    sysadmin add -c /etc/ckan/ckan.ini admin password=12345678 email=admin@localhost
```

Login to CKAN at http://nginx:8080 with username `admin` and password `12345678`

To start the jobs server for uploading to the datastore DB:

```
docker-compose up -d jobs
```

### Optionally, use make commands

The following commands use the `vital-strategies` project template as an example. Replace `vital-strategies` with the name of your project template. **Note**: Using the commands below still requires adding `nginx` to your hosts file as shown above.

Build the images:

```
make build O=vital-strategies
```

Start the environment (this will also build the images if they haven't been built yet):

```
make start O=vital-strategies
```

Stop the environment:

```
make stop O=vital-strategies
```

Enter a container:

```
make shell O=vital-strategies S=SERVICE_NAME
```

Make a user:

```
make user O=vital-strategies U=USER_NAME P=PASSWORD E=EMAIL
```

Make a user a sysadmin:

```
make sysadmin O=vital-strategies U=USER_NAME
```

Remove the containers and volumes:

```
make remove O=vital-strategies
```

Remove the associated images:

```
make remove-images O=vital-strategies
```

Completely remove and then rebuild the environment (this will remove containers, volumes, and images):

```
make clean-rebuild O=vital-strategies
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
cp docker-compose/ckan-conf-templates/ckan.ini.template \
   docker-compose/ckan-conf-templates/my-ckan-ckan.ini.template
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

## Migrating to CKAN 2.10 and Python 3

>**Note**: As of January 1, 2020, Python 2 is no longer officially supported. If you're running CKAN 2.7 with Python 2, it's highly recommended to migrate to CKAN 2.10 with Python 3. The latest version of this repo also no longer supports CKAN < 2.10 and Python < 3. If you must stick with those versions for now, you will need to maintain your local copy of this repo yourself.

All of the following commands should be run in `ckan-cloud-docker` (unless stated otherwise). In the examples below, I'm using the `vital-strategies` project template as an example. Replace `vital-strategies` with the name of your project template.

>**Note**: Depending on any custom configurations you have, you might need to adjust the variables in `db/migration/upgrade_databases.sh` (and others, such as your custom `docker-compose` file, or your custom `.ini` file) to match your setup.

1. Start up your _current_ instance (if it's not running already, **don't pull the latest changes yet**): `make start O=vital-strategies`
2. Pull the latest changes: `git pull` (**Important**: don't stop your instance yet—make sure it's still running when you pull this, as you need to run the next command on your _current_ instance, and the command only exists on the new branch)
3. Backup the DBs: `make backup-db O=vital-strategies` (confirm that you have `ckan.dump`, `datastore.dump` and `ckan_data.tar.gz` in the current directory after running this command)
4. Stop the containers: `make stop O=vital-strategies`
5. (optional and not recommended) If you don't want to use `datapusher-plus`, you will need to export this variable every time you start, stop, or build CKAN: `export DATAPUSHER_TYPE=datapusher`
6. Create secrets: `make secret` (follow the prompts)
7. Clean and rebuild: `make clean-rebuild O=vital-strategies`
8. Run the upgrade script: `make upgrade-db O=vital-strategies`
    - If you have set custom DB names and users, you will need to pass in these options as needed: `make upgrade-db O=vital-strategies CKAN_DB_NAME=<CKAN_DB_NAME> DB_USERNAME=<DB_USERNAME> CKAN_DB_USERNAME=<CKAN_DB_USERNAME> DATASTORE_DB_NAME=<DATASTORE_DB_NAME> DATASTORE_DB_USERNAME=<DATASTORE_DB_USERNAME>`— the default values are: `CKAN_DB_NAME=ckan`, `DB_USERNAME=postgres`, `CKAN_DB_USERNAME=ckan`, `DATASTORE_DB_NAME=datastore`, `DATASTORE_DB_USERNAME=postgres`
    - Copy the API token that's output at the end for step 10 
9. Stop the containers: `make stop O=vital-strategies`
10. Run `make secret` again and paste the token when prompted (step 13—"Enter Datapusher API token")
11. Start the containers: `make start O=vital-strategies`
12. Test and confirm that the migration was successful

>**Note**: The first time you visit the DataStore tab for a given resource, it will say "Error: cannot connect to datapusher". If you click "Upload to DataStore", this error will go away and the process will complete as expected.

>**Important**: It's recommended to make copies of `ckan.dump`, `datastore.dump` and `ckan_data.tar.gz` and move them off of the server, if possible. If anything goes wrong, and you must revert to the old CKAN 2.7 instance, you can restore it by following the steps below:

1. Stop the containers: `make stop O=vital-strategies`
2. Checkout the last CKAN 2.7 commit: `git checkout d3bdc178a1726ada331b47157b92123cdec82b12`
3. Create secrets (you probably don't need to do this, but go through the process and make sure your previously entered values are correct): `make secret` (follow the prompts)
4. Clean and rebuild: `make clean-rebuild O=vital-strategies`
5. Restore the DBs (_note_: the prior version of this repo doesn't have a command for this—you must do it manually):
    1. Restore the CKAN DB: `docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.<YOUR_PROJECT>-theme.yaml exec -T db pg_restore -U postgres --verbose --create --clean --if-exists -d postgres < ckan.dump`
    2. Restore the DataStore DB: `docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.<YOUR_PROJECT>-theme.yaml exec -T datastore-db pg_restore -U postgres --verbose --create --clean --if-exists -d postgres < datastore.dump`
    3. Restore the CKAN data:
        1. `docker cp ckan_data.tar.gz $(docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.<YOUR_PROJECT>-theme.yaml ps -q ckan):/tmp/ckan_data.tar.gz`
        2. `docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.<YOUR_PROJECT>-theme.yaml exec -T ckan bash -c "tar -xzf /tmp/ckan_data.tar.gz -C /tmp/ && cp -r /tmp/data/* /var/lib/ckan/data/ && chown -R ckan:ckan /var/lib/ckan/data"`
    4. Set datastore permissions:
        1. Enter your `ckan` container: `docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.<YOUR_PROJECT>-theme.yaml exec ckan bash`
        2. Create a new file in your `ckan` container, `ckan.sql`, with the following contents:
           ```
           \connect "datastore"

           -- revoke permissions for the read-only user
           REVOKE CREATE ON SCHEMA public FROM PUBLIC;
           REVOKE USAGE ON SCHEMA public FROM PUBLIC;

           GRANT CREATE ON SCHEMA public TO "postgres";
           GRANT USAGE ON SCHEMA public TO "postgres";

           -- grant select permissions for read-only user
           GRANT CONNECT ON DATABASE "datastore" TO "readonly";
           GRANT USAGE ON SCHEMA public TO "readonly";

           -- grant access to current tables and views to read-only user
           GRANT SELECT ON ALL TABLES IN SCHEMA public TO "readonly";

           -- grant access to new tables and views by default
           ALTER DEFAULT PRIVILEGES FOR USER "postgres" IN SCHEMA public
              GRANT SELECT ON TABLES TO "readonly";

           -- a view for listing valid table (resource id) and view names
           CREATE OR REPLACE VIEW "_table_metadata" AS
               SELECT DISTINCT
                   substr(md5(dependee.relname || COALESCE(dependent.relname, '')), 0, 17) AS "_id",
                   dependee.relname AS name,
                   dependee.oid AS oid,
                   dependent.relname AS alias_of
                   -- dependent.oid AS oid
               FROM
                   pg_class AS dependee
                   LEFT OUTER JOIN pg_rewrite AS r ON r.ev_class = dependee.oid
                   LEFT OUTER JOIN pg_depend AS d ON d.objid = r.oid
                   LEFT OUTER JOIN pg_class AS dependent ON d.refobjid = dependent.oid
               WHERE
                   (dependee.oid != dependent.oid OR dependent.oid IS NULL) AND
                   (dependee.relname IN (SELECT tablename FROM pg_catalog.pg_tables)
                       OR dependee.relname IN (SELECT viewname FROM pg_catalog.pg_views)) AND
                   dependee.relnamespace = (SELECT oid FROM pg_namespace WHERE nspname='public')
                       ORDER BY dependee.oid DESC;
           ALTER VIEW "_table_metadata" OWNER TO "postgres";
           GRANT SELECT ON "_table_metadata" TO "readonly";
           ```
        3. While still in your `ckan` container, get your `sqlalchemy.url`: `cat /etc/ckan/production.ini | grep sqlalchemy.url` (for example, `postgresql://ckan:123456@db/ckan`)
        4. Set the permissions by running: `cat ckan.sql | psql <YOUR_SQLALCHEMY_URL>` (for example, `cat ckan.sql | psql postgresql://ckan:123456@db/ckan`)
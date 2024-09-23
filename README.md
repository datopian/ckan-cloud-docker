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
      - ./traefik/traefik.toml.template:/traefik.toml.template
      #- ./traefik/traefik.dev.toml:/traefik.dev.toml # Uncomment this line to bypass certificates for local development
      - ./traefik/acme.json:/acme.json
      - ./cca-operator/templater.sh:/templater.sh
      - ./docker-compose/traefik-secrets.sh:/traefik-secrets.sh
      - ./traefik/entrypoint.sh:/entrypoint.sh
    networks:
      - ckan-multi
    entrypoint: ["/bin/sh", "-c", "/entrypoint.sh"]
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
        CKAN_BRANCH: ckan-2.10.4
        EXTRA_PACKAGES: cron
        EXTRA_FILESYSTEM: "./overrides/vital-strategies/filesystem/"
        POST_INSTALL: |
          install_standard_ckan_extension_github -r datopian/ckanext-querytool -b cc6c8e6f19f59e6842d370bf7ac87d94e37a2831 &&\
          install_standard_ckan_extension_github -r ckan/ckanext-geoview && \
          install_standard_ckan_extension_github -r datopian/ckanext-sentry -b 2.10 && \
          install_standard_ckan_extension_github -r datopian/ckanext-gtm && \
          install_standard_ckan_extension_github -r datopian/ckanext-s3filestore -b ckan-2.10 && \
          cd ~/venv/src/ckanext-querytool && ~/venv/bin/python setup.py compile_catalog -l en -f && \
          cd ~/venv/src/ckanext-querytool && ~/venv/bin/python setup.py compile_catalog -l es -f && \
          cd ~/venv/src/ckanext-querytool && ~/venv/bin/python setup.py compile_catalog -l fr -f && \
          cd ~/venv/src/ckanext-querytool && ~/venv/bin/python setup.py compile_catalog -l km -f && \
          cd ~/venv/src/ckanext-querytool && ~/venv/bin/python setup.py compile_catalog -l pt_BR -f && \
          cd ~/venv/src/ckanext-querytool && ~/venv/bin/python setup.py compile_catalog -l zh_Hans_CN -f
    environment:
      - CKAN_CONFIG_TEMPLATE_PREFIX=vital-strategies-theme-
    # ports: # Uncomment these lines expose CKAN on localhost for local development
    #   - 5000:5000
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

>**Important**: While following the migration steps, you will create backups of the DBs to migrate to the new upgraded CKAN instance. A more robust backup is recommended, in the case that you need to revert to the old CKAN 2.7 instance. It's recommended to either take a snapshot (or similar) of your server before beginning the migration, or to make a full copy of `/var/lib/docker` (or wherever your Docker data is stored) to ensure you can revert if needed. If your cloud server doesn't have space to store the copy (the copy will likely require at least 50GB of free space), you will need to copy it to another server or storage location (e.g., S3, Google Cloud Storage, or locally using `scp`, `rsync`, etc.). For steps on how to revert to the old CKAN 2.7 instance _without_ a full system or Docker data backup, see the [Reverting to the old CKAN 2.7 instance](#reverting-to-the-old-ckan-27-instance) section below.

1. Start up your _current_ instance (if it's not running already, **don't pull the latest changes yet**): `make start O=vital-strategies`
2. Reset any repo changes that might have accidentally been commited: `git reset --mixed HEAD`
3. Create a diff file with any changes in the current branch (for example, values manually added to `.ini` files, etc.—this file will be read later in a script): `git diff > configs.diff`
4. Stash all local changes: `git stash`
5. Pull the latest changes: `git pull` (**Important**: Don't stop your instance yet—make sure it's still running when you pull this, as you need to run the next few commands on your _current_ instance, and the commands only exist in the latest codebase)
6. Run the config updater script: `make config-upgrade` (this will output any variables that have changed—you will need to enter these values when you run `make secret` later)
7. Backup the DBs: `make backup-db O=vital-strategies` (confirm that you have `ckan.dump`, `datastore.dump` and `ckan_data.tar.gz` in the current directory after running this command—you can use `ls *.dump` and `ls *.tar.gz` to confirm that the files exist)
8. Stop the containers: `make stop O=vital-strategies`
9. (optional and not recommended) If you don't want to use [DataPusher+](https://github.com/dathere/datapusher-plus), you will need to export the following variable every time you start, stop, or build CKAN: `export DATAPUSHER_TYPE=datapusher`
10. Create secrets: `make secret` (follow the prompts and make sure to add any values that were output from the config updater script in step 6)
11. Clean and rebuild: `make clean-rebuild O=vital-strategies`
12. Run the upgrade script: `make upgrade-db O=vital-strategies`
    - If you have set custom DB names and users, you will need to pass in these options as needed: `make upgrade-db O=vital-strategies CKAN_DB_NAME=<CKAN_DB_NAME> DB_USERNAME=<DB_USERNAME> CKAN_DB_USERNAME=<CKAN_DB_USERNAME> DATASTORE_DB_NAME=<DATASTORE_DB_NAME> DATASTORE_DB_USERNAME=<DATASTORE_DB_USERNAME>`— the default values are: `CKAN_DB_NAME=ckan`, `DB_USERNAME=postgres`, `CKAN_DB_USERNAME=ckan`, `DATASTORE_DB_NAME=datastore`, `DATASTORE_DB_USERNAME=postgres`
    - Copy the API token that's output at the end for step 10 
13. Stop the containers: `make stop O=vital-strategies`
14. Run `make secret` again and paste the token when prompted (step 13—"Enter Datapusher API token")
15. (optional) If you use extensions like Sentry, S3filestore, or Google Analytics, you will need to manually re-enable them in your `.ini` file (for example, `docker-compose/ckan-conf-templates/vital-strategies-theme-ckan.ini.template`). This is because these plugins cannot be enabled on the first run of the new CKAN instance, as the DB will not initialize properly. You can enable them by adding the following lines to your `.ini` file. If you have a custom theme extension, e.g., `querytool`, it must be the last item in the list. For example, if you want to add all 3 of the examples I mentioned, you would update the following line:
    ```
    ckan.plugins = image_view text_view recline_view datastore datapusher resource_proxy geojson_view querytool
    ```
    to:
    ```
    ckan.plugins = image_view text_view recline_view datastore datapusher resource_proxy geojson_view sentry s3filestore googleanalytics querytool
    ```
    **Note**: To edit the file, you will need to use `nano`, `vi` or another command line text editor. Both `nano` and `vi` should be available on most modern Linux operating systems by default. `nano` is recommended for less experienced users, as it's more user-friendly. Your `.ini` file will be located in `docker-compose/ckan-conf-templates/<YOUR_PROJECT>-theme-ckan.ini.template`.

    To open and edit the file with `nano`, run `nano docker-compose/ckan-conf-templates/vital-strategies-theme-ckan.ini.template`. Make your changes, and then, to save and exit, press `ctrl` + `x`, then `y`, then `enter`. If you make a mistake, press `ctrl` + `x`, then `n` to exit without saving.

    To open and edit the file with `vi`, run `vi docker-compose/ckan-conf-templates/vital-strategies-theme-ckan.ini.template`. To edit the file, press `i` to enter insert mode. To save and exit, press `esc` to exit insert mode, then type `:wq` and press `enter`. If you make a mistake, press `esc` to exit insert mode, then type `:q!` and press `enter` to exit without saving.
16. Start the containers: `make start O=vital-strategies`
17. Test and confirm that the migration was successful

>**Note**: After the migration, the first time you visit the DataStore tab for any pre-existing resources, you might see "Error: cannot connect to datapusher". If you click "Upload to DataStore", this error should go away and the process will complete as expected. It's not necessary to go through the resources and remove this error message, as there's actually no issue with DataStore/DataPusher and your old data (it's there and should be working fine)—it's just a UI bug due to switching DBs, which confuses DataPusher. It will work as expected for both existing and new resources.

### Reverting to the old CKAN 2.7 instance

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
#!/bin/bash

COMPOSE_FILES=$1
CKAN_DB_NAME=$2
CKAN_DB_USERNAME=$3
DB_USERNAME=$4
DATASTORE_DB_NAME=$5
DATSTORE_DB_USERNAME=$6

CKAN_BACKUP_FILE="ckan.dump"
DATASTORE_BACKUP_FILE="datastore.dump"
CKAN_DATA_BACKUP_FILE="ckan_data.tar.gz"
CKAN_SERVICE="ckan"
DB_SERVICE="db"
DATASTORE_SERVICE="datastore-db"
CKAN_CONFIG_PATH="/etc/ckan/ckan.ini"
DB_SERVICE_ID=$(docker-compose ${COMPOSE_FILES} ps -q ${DB_SERVICE})
DATASTORE_SERVICE_ID=$(docker-compose ${COMPOSE_FILES} ps -q ${DATASTORE_SERVICE})
CKAN_SERVICE_ID=$(docker-compose ${COMPOSE_FILES} ps -q ${CKAN_SERVICE})

if [ ! -f $CKAN_BACKUP_FILE ]; then
    echo ""
    echo "### CKAN backup file not found."
    echo ""
    exit 1
fi

if [ ! -f $DATASTORE_BACKUP_FILE ]; then
    echo ""
    echo "### Datastore backup file not found."
    echo ""
    exit 1
fi

if [ ! -f $CKAN_DATA_BACKUP_FILE ]; then
    echo ""
    echo "### CKAN data backup file not found."
    echo ""
    exit 1
fi

reset_database() {
    local db_name=$1
    local service_name=$2
    local db_username=$3

    echo ""
    echo "### Disconnecting users from database ${db_name} on service ${service_name}..."
    echo ""
    docker-compose ${COMPOSE_FILES} exec -T ${service_name} psql -U ${db_username} -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='${db_name}';"

}

reset_database ${CKAN_DB_NAME} ${DB_SERVICE} ${CKAN_DB_USERNAME}
reset_database ${DATASTORE_DB_NAME} ${DATASTORE_SERVICE} ${DATSTORE_DB_USERNAME}

echo ""
echo "### ROLE and DATABASE for datapusher_jobs created in Datastore database."

echo ""
echo "### Restoring the CKAN DB from backup..."
echo ""

docker cp ${CKAN_BACKUP_FILE} ${DB_SERVICE_ID}:/${CKAN_BACKUP_FILE}
docker-compose ${COMPOSE_FILES} exec -T ${DB_SERVICE} pg_restore -U postgres --verbose --create --clean --if-exists -d postgres /ckan.dump

echo ""
echo "### Restoring CKAN DB from backup completed."

echo ""
echo "### Restoring the Datastore DB from backup..."
echo ""

docker cp ${DATASTORE_BACKUP_FILE} ${DATASTORE_SERVICE_ID}:/${DATASTORE_BACKUP_FILE}
docker-compose ${COMPOSE_FILES} exec -T ${DATASTORE_SERVICE} pg_restore -U postgres --verbose --create --clean --if-exists -d postgres /datastore.dump

echo ""
echo "### Restoring Datastore DB from backup completed."

echo ""
echo "### Create ROLE and DATABASE for datapusher_jobs in Datastore database..."
echo ""

docker-compose ${COMPOSE_FILES} exec -T ${DATASTORE_SERVICE} psql -U ${DB_USERNAME} -c "CREATE ROLE datapusher_jobs WITH LOGIN PASSWORD '123456';"
docker-compose ${COMPOSE_FILES} exec -T ${DATASTORE_SERVICE} psql -U ${DB_USERNAME} -c "CREATE DATABASE datapusher_jobs OWNER datapusher_jobs ENCODING 'utf8';"

echo ""
echo "### Restoring data files to CKAN..."
echo ""

docker cp ${CKAN_DATA_BACKUP_FILE} ${CKAN_SERVICE_ID}:/${CKAN_DATA_BACKUP_FILE}

docker-compose ${COMPOSE_FILES} exec -T ${CKAN_SERVICE} bash -c "mkdir -p /var/lib/ckan/data && tar -xzf /ckan_data.tar.gz --strip-components=1 -C /var/lib/ckan/data && chown -R ckan:ckan /var/lib/ckan/data"

echo ""
echo "### Data files restored to CKAN."

echo ""
echo "### Running CKAN migration scripts..."
echo ""

docker-compose ${COMPOSE_FILES} exec -T ${CKAN_SERVICE} ckan -c ${CKAN_CONFIG_PATH} db upgrade

echo ""
echo "### CKAN migration scripts completed."

echo ""
echo "### Rebuilding CKAN search index..."
echo ""

docker-compose ${COMPOSE_FILES} exec -T ${CKAN_SERVICE} ckan -c ${CKAN_CONFIG_PATH} search-index rebuild

echo ""
echo "### CKAN search index rebuilt."

echo ""
echo "### Create a sysadmin datapusher user in CKAN..."
echo ""

RANDOM_PASSWORD=$(tr </dev/urandom -dc A-Za-z0-9 | head -c 12)
docker-compose ${COMPOSE_FILES} exec -T ${CKAN_SERVICE} bash -c "yes y | ckan -c $CKAN_CONFIG_PATH sysadmin add datapusher email=datapusher@localhost password=$RANDOM_PASSWORD"

echo ""
echo "### Datapusher user created in CKAN."

echo ""
echo "### Creating API key for datapusher user in CKAN..."
echo ""

CKAN_API_KEY=$(docker-compose ${COMPOSE_FILES} exec -T ${CKAN_SERVICE} ckan -c $CKAN_CONFIG_PATH user token add datapusher datapusher | tail -n 1 | tr -d '\t')

echo ""
echo "### API key for datapusher user: $CKAN_API_KEY"

echo ""
echo "### Setting up ckan.datapusher.api_token in CKAN config file $CKAN_CONFIG_PATH..."
echo ""

docker-compose ${COMPOSE_FILES} exec -T ${CKAN_SERVICE} ckan config-tool ${CKAN_CONFIG_PATH} -e "ckan.datapusher.api_token=$CKAN_API_KEY"

echo "### CKAN datapusher API key set."

echo ""
echo "### Migrating CKAN activity stream..."
echo ""

docker-compose ${COMPOSE_FILES} exec -T ${CKAN_SERVICE} bash -c "source /usr/lib/ckan/venv/bin/activate && yes y | python /usr/lib/ckan/venv/src/ckan/ckan/migration/migrate_package_activity.py --config=${CKAN_CONFIG_PATH}"

echo ""
echo "### CKAN activity stream migrated."

echo ""
echo "### Fix datastore permissions..."

cat db/migration/datastore-permissions.sql | docker-compose ${COMPOSE_FILES} exec -T ${DATASTORE_SERVICE} psql -U postgres -d datastore

echo ""
echo "### Datastore permissions fixed."

echo ""
echo "####### All tasks completed successfully. #######"
echo "#################################################"
echo ""
echo "Don't forget to re-run 'make secrets' again to add the datapusher API token!"
echo ""
echo "1. Stop the containers: 'make stop O=<YOUR_PROJECT>'"
echo "2. Copy the API token below and run 'make secret' (paste it at step 13)"
echo "   API key: $CKAN_API_KEY"
echo "3. Start the containers again: 'make start O=<YOUR_PROJECT>'"
echo ""
echo "#################################################"
echo ""

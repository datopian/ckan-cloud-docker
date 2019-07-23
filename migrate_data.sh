#!/usr/bin/env bash

source $CKAN_K8S_SECRETS

DB_BACKUP=${1}
DATASTORE_DB_BACKUP=${2}
# Switch to postgres user
DB="${SQLALCHEMY_URL/:\/\/[^:]*:/:\/\/postgres:}"
# Remove db name from URI to delete
DB="${DB/\/ckan/}"
DATASTORE_DB="${CKAN_DATASTORE_WRITE_URLB/\/datastore/}"

echo $DB

# recover DB
if [ "$DB_BACKUP" != "" ]; then
  wget -O db_backup.gz $DB_BACKUP && gunzip db_backup.gz
  psql $DB -c "SELECT pg_terminate_backend (pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = 'ckan'"
  psql $DB -c "DROP DATABASE ckan;"
  psql $DB -c "CREATE DATABASE ckan;"
  psql $SQLALCHEMY_URL -f db_backup ckan
  psql $DB/ckan -c "CREATE EXTENSION postgis;"
  psql $DB/ckan -c "CREATE EXTENSION postgis_topology;"
fi

# recover datastore DB
if [ "$DATASTORE_DB_BACKUP" != "" ]; then
  psql $DB -c "SELECT pg_terminate_backend (pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = 'datastore'"
  psql $DB -c "DROP DATABASE datastore;"
  psql $DB -c "CREATE DATABASE datastore;"
  wget -O db_datastore_backup.gz $DATASTORE_DB_BACKUP && gunzip db_datastore_backup.gz
  psql $CKAN_DATASTORE_WRITE_URL -f db_datastore_backup ckan
fi

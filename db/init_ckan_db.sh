while ! pg_isready; do
  echo waiting for DB to accept connections...
  sleep 1
done
sleep 2

if [ -z "${DATASTORE_RO_USER}" ]; then
    echo Initializing CKAN DB &&\
    echo Creating db &&\
    createdb ckan -E utf-8 &&\
    echo Creating role "create role ckan with login password '${POSTGRES_PASSWORD}'" &&\
    psql -c "create role ckan with login password '${POSTGRES_PASSWORD}';" &&\
    echo Granting privileges &&\
    psql -c 'GRANT ALL PRIVILEGES ON DATABASE "ckan" to ckan;' &&\
    echo Successfully initialized the CKAN DB

else
    echo Initializing datastore DB &&\
    echo Creating db &&\
    createdb datastore -E utf-8 &&\
    echo creating readonly user &&\
    psql -c "create role ${DATASTORE_RO_USER} with login password '${DATASTORE_RO_PASSWORD}';" &&\
    echo setting datastore permissions &&\
    bash /db-scripts/templater.sh /db-scripts/datastore-permissions.sql.template \
        | psql --set ON_ERROR_STOP=1 &&\
    echo Successfully initialized the datastore DB

fi

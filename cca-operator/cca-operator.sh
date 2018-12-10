#!/usr/bin/env bash

source functions.sh

if [ "${1}" == "initialize-ckan-env-vars" ]; then
    ENV_VARS_SECRET="${2}"
    [ -z "${ENV_VARS_SECRET}" ] && echo usage: cca-operator initialize-ckan-env-vars '<ENV_VARS_SECRET_NAME>' && exit 1
    if ! kubectl $KUBECTL_GLOBAL_ARGS get secret $ENV_VARS_SECRET; then
        POSTGRES_PASSWORD=`python -c "import binascii,os;print(binascii.hexlify(os.urandom(12)))"`
        DATASTORE_POSTGRES_PASSWORD=`python -c "import binascii,os;print(binascii.hexlify(os.urandom(12)))"`
        DATASTORE_RO_PASSWORD=`python -c "import binascii,os;print(binascii.hexlify(os.urandom(12)))"`
        if [ -z "${CKAN_CLOUD_POSTGRES_HOST}" ]; then
            echo Using self-hosted DB
            POSTGRES_USER=ckan
            POSTGRES_DB_NAME="${POSTGRES_USER}"
            POSTGRES_HOST=db
            DATASTORE_RO_USER=readonly
            DATASTORE_POSTGRES_USER=postgres
            CENTRALIZED_DB=0
        else
            echo Using centralized DB
            if [ -z "${CKAN_CLOUD_INSTANCE_ID}" ]; then
                POSTGRES_USER=`python -c "import binascii,os;print(binascii.hexlify(os.urandom(8)))"`
                POSTGRES_USER="ckan-${POSTGRES_USER}"
            else
                POSTGRES_USER="${CKAN_CLOUD_INSTANCE_ID}"
            fi
            ! create_db "${CKAN_CLOUD_POSTGRES_HOST}" "${CKAN_CLOUD_POSTGRES_USER:-postgres}" "${POSTGRES_USER}" "${POSTGRES_PASSWORD}" \
                && exit 1
            POSTGRES_DB_NAME="${POSTGRES_USER}"
            POSTGRES_HOST="${CKAN_CLOUD_POSTGRES_HOST}"
            DATASTORE_RO_USER="${POSTGRES_DB_NAME}-datastore-readonly"
            DATASTORE_POSTGRES_USER="${POSTGRES_DB_NAME}-datastore"
            ! create_datastore_db "${POSTGRES_HOST}" "${CKAN_CLOUD_POSTGRES_USER:-postgres}" "${POSTGRES_DB_NAME}" \
                                  "${DATASTORE_POSTGRES_USER}" "${DATASTORE_POSTGRES_PASSWORD}" \
                                  "${DATASTORE_RO_USER}" "${DATASTORE_RO_PASSWORD}" \
                && exit 1
            CENTRALIZED_DB=1
        fi
        if [ -z "${CKAN_CLOUD_SOLR_HOST}" ]; then
            echo using self-hosted solr
            SOLR_URL="http://solr:8983/solr/ckan"
            CENTRALIZED_SOLR=0
        else
            echo using centralized solr cloud
            if [ -z "${CKAN_CLOUD_INSTANCE_ID}" ]; then
                SOLRCLOUD_COLLECTION=`python -c "import binascii,os;print(binascii.hexlify(os.urandom(8)))"`
                SOLRCLOUD_COLLECTION="ckan-${SOLRCLOUD_COLLECTION}"
            else
                SOLRCLOUD_COLLECTION="${CKAN_CLOUD_INSTANCE_ID}"
            fi
            SOLR_URL="http://${CKAN_CLOUD_SOLR_HOST}:${CKAN_CLOUD_SOLR_PORT:-8983}/solr/${SOLRCLOUD_COLLECTION}"
            CENTRALIZED_SOLR=1
        fi
        echo "Creating ckan env vars secret ${ENV_VARS_SECRET}"
        ! kubectl $KUBECTL_GLOBAL_ARGS create secret generic $ENV_VARS_SECRET \
                  --from-literal=CKAN_APP_INSTANCE_UUID=`python -c "import uuid;print(uuid.uuid1())"` \
                  --from-literal=CKAN_BEAKER_SESSION_SECRET=`python -c "import binascii,os;print(binascii.hexlify(os.urandom(25)))"` \
                  --from-literal=POSTGRES_PASSWORD=${POSTGRES_PASSWORD} \
                  --from-literal=POSTGRES_USER=${POSTGRES_USER} \
                  --from-literal=POSTGRES_HOST=${POSTGRES_HOST} \
                  --from-literal=POSTGRES_DB_NAME=${POSTGRES_DB_NAME} \
                  --from-literal=DATASTORE_POSTGRES_PASSWORD=${DATASTORE_POSTGRES_PASSWORD} \
                  --from-literal=DATASTORE_POSTGRES_USER=${DATASTORE_POSTGRES_USER} \
                  --from-literal=DATASTORE_RO_USER=${DATASTORE_RO_USER} \
                  --from-literal=DATASTORE_RO_PASSWORD=${DATASTORE_RO_PASSWORD} \
                  --from-literal=SOLR_URL=${SOLR_URL} \
            && echo Failed to create ckan env vars secret && exit 1
        ckan_cloud_log '{"event":"ckan-env-vars-created", "env-vars-secret-name": "${ENV_VARS_SECRET}",
                         "centralized_db": "'${CENTRALIZED_DB}'", "centralized_solr": "'${CENTRALIZED_SOLR}'"}'
        echo Created ckan env vars secret && exit 0
    else
        ckan_cloud_log '{"event":"ckan-env-vars-exists", "env-vars-secret-name": "'${ENV_VARS_SECRET}'"}'
        echo Ckan env vars secret already exists && exit 0
    fi

elif [ "${1}" == "initialize-ckan-secrets" ]; then
    ENV_VARS_SECRET="${2}"
    CKAN_SECRETS_SECRET="${3}"
    ( [ -z "${ENV_VARS_SECRET}" ] || [ -z "${CKAN_SECRETS_SECRET}" ] ) \
        && echo usage: cca-operator initialize-ckan-secrets '<ENV_VARS_SECRET_NAME>' '<CKAN_SECRETS_SECRET_NAME>' \
        && exit 1
    if ! kubectl $KUBECTL_GLOBAL_ARGS get secret "${CKAN_SECRETS_SECRET}"; then
        echo Creating ckan secrets secret $CKAN_SECRETES_SECRET from env vars secret $ENV_VARS_SECRET
        ! export_ckan_env_vars $ENV_VARS_SECRET && exit 1
        TEMPFILE=`mktemp`
        echo "export BEAKER_SESSION_SECRET=${CKAN_BEAKER_SESSION_SECRET}
export APP_INSTANCE_UUID=${CKAN_APP_INSTANCE_UUID}
export SQLALCHEMY_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST:-db}/${POSTGRES_DB_NAME:-ckan}
export CKAN_DATASTORE_WRITE_URL=postgresql://${DATASTORE_POSTGRES_USER}:${DATASTORE_POSTGRES_PASSWORD}@${POSTGRES_HOST:-datastore-db}/${DATASTORE_POSTGRES_USER:-datastore}
export CKAN_DATASTORE_READ_URL=postgresql://${DATASTORE_RO_USER}:${DATASTORE_RO_PASSWORD}@${POSTGRES_HOST:-datastore-db}/${DATASTORE_POSTGRES_USER:-datastore}
export SOLR_URL=${SOLR_URL}
export CKAN_REDIS_URL=redis://redis:6379/1
export CKAN_DATAPUSHER_URL=
export SMTP_SERVER=
export SMTP_STARTTLS=
export SMTP_USER=
export SMTP_PASSWORD=
export SMTP_MAIL_FROM=" > $TEMPFILE
        cat $TEMPFILE
        kubectl $KUBECTL_GLOBAL_ARGS create secret generic "${CKAN_SECRETS_SECRET}" --from-file=secrets.sh=$TEMPFILE
        CKAN_SECRET_RES="$?"
        rm $TEMPFILE
        [ "$CKAN_SECRET_RES" != "0" ] && echo failed to create ckan secrets secret && exit 1
        ckan_cloud_log '{"event":"ckan-secrets-created", "secrets-secret-name": "'${CKAN_SECRETES_SECRET}'"}'
        echo Great Success
        echo Created new ckan secrets secret: $CKAN_SECRETS_SECRET
        echo Please update the relevant values.yaml file with the new secret name
        exit 0
    else
        ckan_cloud_log '{"event":"ckan-secrets-exists", "secrets-secret-name": "'${CKAN_SECRETES_SECRET}'"}'
        echo Ckan secrets secret $CKAN_SECRETES_SECRET already exists
        exit 0
    fi

elif [ "${1}" == "get-ckan-secrets" ]; then
    CKAN_SECRETS_SECRET="${2}"
    OUTPUT_FILE="${3}"
    ( [ -z "${OUTPUT_FILE}" ] || [ -z "${CKAN_SECRETS_SECRET}" ] ) \
        && echo usage: ckan-operator get-ckan-secrets '<CKAN_SECRETS_SECRET_NAME>' '<SECRETS_SH_OUTPUT_FILE>' \
        && exit 1
    echo Getting ckan secrets from $CKAN_SECRETS_SECRET to $OUTPUT_FILE
    ! SECRETS_JSON=`get_secrets_json $CKAN_SECRETS_SECRET` \
        && echo could not find ckan secrets $CKAN_SECRETS_SECRET && exit 1
    ! get_secret_from_json "${SECRETS_JSON}" '"secrets.sh"' > $OUTPUT_FILE \
        && echo failed to parse secrets && exit 1
    ckan_cloud_log '{"event":"got-ckan-secrets", "secrets-secret-name": "'${CKAN_SECRETES_SECRET}'"}'
    echo Successfully copied secrets
    exit 0

elif [ "${1}" == "" ] || [ "${1}" == "-h" ] || [ "${1}" == "--help" ]; then
    echo Available commands:
    echo
    for F in `ls *.sh`; do
        [ "${F}" != "functions.sh" ] && [ "${F}" != "cca-operator.sh" ] && [ "${F}" != "templater.sh" ] &&\
        ./${F} --help
    done

else
    ! bash "$@" && exit 1
    exit 0

fi

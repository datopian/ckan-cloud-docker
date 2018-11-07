#!/usr/bin/env bash

source functions.sh

if [ "${1}" == "initialize-ckan-env-vars" ]; then
    ENV_VARS_SECRET="${2}"
    [ -z "${ENV_VARS_SECRET}" ] && echo usage: cca-operator initialize-ckan-env-vars '<ENV_VARS_SECRET_NAME>' && exit 1
    if ! kubectl get secret $ENV_VARS_SECRET; then
        echo "Creating ckan env vars secret ${ENV_VARS_SECRET}"
        ! kubectl create secret generic $ENV_VARS_SECRET \
                  --from-literal=CKAN_APP_INSTANCE_UUID=`python -c "import uuid;print(uuid.uuid1())"` \
                  --from-literal=CKAN_BEAKER_SESSION_SECRET=`python -c "import binascii,os;print(binascii.hexlify(os.urandom(25)))"` \
                  --from-literal=POSTGRES_PASSWORD=`python -c "import binascii,os;print(binascii.hexlify(os.urandom(12)))"` \
                  --from-literal=POSTGRES_USER=ckan \
                  --from-literal=DATASTORE_POSTGRES_PASSWORD=`python -c "import binascii,os;print(binascii.hexlify(os.urandom(12)))"` \
                  --from-literal=DATASTORE_POSTGRES_USER=postgres \
                  --from-literal=DATASTORE_RO_USER=readonly \
                  --from-literal=DATASTORE_RO_PASSWORD=`python -c "import binascii,os;print(binascii.hexlify(os.urandom(12)))"` \
            && echo Failed to create ckan env vars secret && exit 1
        echo Created ckan env vars secret && exit 0
    else
        echo Ckan env vars secret already exists && exit 0
    fi

elif [ "${1}" == "initialize-ckan-secrets" ]; then
    ENV_VARS_SECRET="${2}"
    CKAN_SECRETS_SECRET="${3}"
    ( [ -z "${ENV_VARS_SECRET}" ] || [ -z "${CKAN_SECRETS_SECRET}" ] ) \
        && echo usage: cca-operator initialize-ckan-secrets '<ENV_VARS_SECRET_NAME>' '<CKAN_SECRETS_SECRET_NAME>' \
        && exit 1
    if ! kubectl get secret "${CKAN_SECRETS_SECRET}"; then
        echo Creating ckan secrets secret $CKAN_SECRETES_SECRET from env vars secret $ENV_VARS_SECRET
        ! export_ckan_env_vars $ENV_VARS_SECRET && exit 1
        TEMPFILE=`mktemp`
        echo "export BEAKER_SESSION_SECRET=${CKAN_BEAKER_SESSION_SECRET}
        export APP_INSTANCE_UUID=${CKAN_APP_INSTANCE_UUID}
        export SQLALCHEMY_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@db/ckan
        export CKAN_DATASTORE_WRITE_URL=postgresql://${DATASTORE_POSTGRES_USER}:${DATASTORE_POSTGRES_PASSWORD}@datastore-db/datastore
        export CKAN_DATASTORE_READ_URL=postgresql://${DATASTORE_RO_USER}:${DATASTORE_RO_PASSWORD}@datastore-db/datastore
        export SOLR_URL=http://solr:8983/solr/ckan
        export CKAN_REDIS_URL=redis://redis:6379/1
        export CKAN_DATAPUSHER_URL=
        export SMTP_SERVER=
        export SMTP_STARTTLS=
        export SMTP_USER=
        export SMTP_PASSWORD=
        export SMTP_MAIL_FROM=" > $TEMPFILE
        kubectl create secret generic "${CKAN_SECRETS_SECRET}" --from-file=secrets.sh=$TEMPFILE
        CKAN_SECRET_RES="$?"
        rm $TEMPFILE
        [ "$CKAN_SECRET_RES" != "0" ] && echo failed to create ckan secrets secret && exit 1
        echo Great Success
        echo Created new ckan secrets secret: $CKAN_SECRETS_SECRET
        echo Please update the relevant values.yaml file with the new secret name
        exit 0
    else
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
    echo Successfully copied secrets
    exit 0

elif [ "${1}" == "" ] || [ "${1}" == "-h" ] || [ "${1}" == "--help" ]; then
    echo Available commands:
    for F in `ls *.sh`; do
        [ "${F}" != "functions.sh" ] && [ "${F}" != "cca-operator.sh" ] && [ "${F}" != "templater.sh" ] &&\
        echo "./${F}"
    done

else
    ! bash "$@" && exit 1
    exit 0

fi

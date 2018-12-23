#!/usr/bin/env bash

[ "${1}" == "--help" ] && echo ./import-db.sh '<INSTANCE_ID>' && exit 0

source functions.sh
! cluster_management_init "${1}" && exit 1

! [ -e "${CKAN_VALUES_FILE}" ] && echo missing values file for instance ${INSTANCE_ID} && exit 1

IMPORT_TYPE=`python3 -c '
import yaml;
print(yaml.load(open("'${CKAN_VALUES_FILE}'"))["import-type"])
' 2>/dev/null`

echo INSTANCE_ID = $INSTANCE_ID
echo IMPORT_TYPE = $IMPORT_TYPE

if [ "${IMPORT_TYPE}" == "envvars" ]; then
    ENVVARS="$(python3 -c '
import yaml;
print(yaml.load(open("'${CKAN_VALUES_FILE}'"))["envvars"])
' 2>/dev/null)"
else
    echo invalid import type: ${IMPORT_TYPE}
    exit 1
fi

eval "${ENVVARS}"

if [ "${2}" == "--datastore" ]; then
    [ -z "${CKAN__DATASTORE__WRITE_URL}" ] && echo missing CKAN__DATASTORE__WRITE_URL env var && exit 1
    SOURCE_DB_URL=$(echo "${CKAN__DATASTORE__WRITE_URL}" | python3 -c 'import sys; print(sys.stdin.read().replace("postgresql://", "postgres://"))')
    CREATE_POSTGRES_USER="${INSTANCE_ID}-datastore"
    CREATE_DB_FUNC="create_db_base"
else
    [ -z "${CKAN_SQLALCHEMY_URL}" ] && echo missing CKAN_SQLALCHEMY_URL env var && exit 1
    SOURCE_DB_URL=$(echo "${CKAN_SQLALCHEMY_URL}" | python3 -c 'import sys; print(sys.stdin.read().replace("postgresql://", "postgres://"))')
    CREATE_POSTGRES_USER="${INSTANCE_ID}"
    CREATE_DB_FUNC="create_db"
fi

SECRET_JSON="$(kubectl -n ckan-cloud get secret ckan-infra -o json)"
POSTGRES_HOST=`get_secret_from_json "${SECRET_JSON}" "POSTGRES_HOST"`
POSTGRES_PASSWORD=`get_secret_from_json "${SECRET_JSON}" "POSTGRES_PASSWORD"`
POSTGRES_USER=`get_secret_from_json "${SECRET_JSON}" "POSTGRES_USER"`

CREATE_POSTGRES_PASSWORD=`python -c "import binascii,os;print(binascii.hexlify(os.urandom(12)))"`

echo importing DB, this may take a while...
set -o pipefail
dump_db_url "${SOURCE_DB_URL}" | PGPASSWORD=$POSTGRES_PASSWORD import_db $POSTGRES_HOST $POSTGRES_USER $CREATE_POSTGRES_USER $CREATE_POSTGRES_PASSWORD $CREATE_DB_FUNC

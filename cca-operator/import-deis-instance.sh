#!/usr/bin/env bash

[ "${1}" == "--help" ] && echo ./import-deis-instance.sh '<INSTANCE_ID>' && exit 0

source functions.sh
! cluster_management_init "${1}" && exit 1

! [ -e "${CKAN_VALUES_FILE}" ] && echo missing values file for instance ${INSTANCE_ID} && exit 1

! [ "$(get_ckan_values_string instance-type)" == "deis-envvars" ] \
    && echo invalid instance-type for import: "$(get_ckan_values_string instance-type)" \
    && exit 1

IMPORT_VALUES="$(
python3 -c 'import yaml;
print(yaml.dump(yaml.load(open("'${CKAN_VALUES_FILE}'")).get("import", ""),
                default_flow_style=False))' 2>/dev/null
)"

GCLOUD_SQL_DB_DUMP_URL="$(echo "${IMPORT_VALUES}" | get_stdin_values_string gcloud_sql_db_dump_url)"
GCLOUD_SQL_DATASTORE_DUMP_URL="$(echo "${IMPORT_VALUES}" | get_stdin_values_string gcloud_sql_datastore_dump_url)"
SOLRCLOUD_COLLECTION_CONFIG_NAME="$(echo "${IMPORT_VALUES}" | get_stdin_values_string solrcloud_collection_config_name)"
CKAN_IMAGE="$(echo "${IMPORT_VALUES}" | get_stdin_values_string ckan_image)"

[ -z "${GCLOUD_SQL_DB_DUMP_URL}" ] && echo missing GCLOUD_SQL_DB_DUMP_URL && exit 1
[ -z "${GCLOUD_SQL_DATASTORE_DUMP_URL}" ] && echo missing GCLOUD_SQL_DATASTORE_DUMP_URL && exit 1
[ -z "${SOLRCLOUD_COLLECTION_CONFIG_NAME}" ] && echo missing SOLRCLOUD_COLLECTION_CONFIG_NAME && exit 1
[ -z "${CKAN_IMAGE}" ] && echo missing CKAN_IMAGE && exit 1

echo getting infra connection details

! INFRA_CONNECTION_DETAILS="$(kubectl get secret -n ckan-cloud ckan-infra -o yaml \
    | python3 -c "import yaml,sys,base64; print(yaml.dump({k: base64.b64decode(v).decode() for k,v in yaml.load(sys.stdin)['data'].items()},default_flow_style=False))")" \
    && echo failed to get infra connection details && exit 1

POSTGRES_HOST="$(echo "${INFRA_CONNECTION_DETAILS}" | get_stdin_values_string POSTGRES_HOST)"
POSTGRES_PASSWORD="$(echo "${INFRA_CONNECTION_DETAILS}" | get_stdin_values_string POSTGRES_PASSWORD)"
POSTGRES_USER="$(echo "${INFRA_CONNECTION_DETAILS}" | get_stdin_values_string POSTGRES_USER)"
SOLR_HTTP_ENDPOINT="$(echo "${INFRA_CONNECTION_DETAILS}" | get_stdin_values_string SOLR_HTTP_ENDPOINT)"
SOLR_REPLICATION_FACTOR="$(echo "${INFRA_CONNECTION_DETAILS}" | get_stdin_values_string SOLR_REPLICATION_FACTOR)"
SOLR_NUM_SHARDS="$(echo "${INFRA_CONNECTION_DETAILS}" | get_stdin_values_string SOLR_NUM_SHARDS)"
GCLOUD_SQL_INSTANCE_NAME="$(echo "${INFRA_CONNECTION_DETAILS}" | get_stdin_values_string GCLOUD_SQL_INSTANCE_NAME)"
GCLOUD_SQL_PROJECT="$(echo "${INFRA_CONNECTION_DETAILS}" | get_stdin_values_string GCLOUD_SQL_PROJECT)"
# GCLOUD_SQL_SERVICE_KEY="$(echo "${INFRA_CONNECTION_DETAILS}" | get_stdin_values_string GCLOUD_SQL_SERVICE_KEY)"
# GCLOUD_SQL_SERVICE_ACCOUNT="$(echo "${INFRA_CONNECTION_DETAILS}" | get_stdin_values_string GCLOUD_SQL_SERVICE_ACCOUNT)"
# GCLOUD_SQL_PROJECT="$(echo "${INFRA_CONNECTION_DETAILS}" | get_stdin_values_string GCLOUD_SQL_PROJECT)"

(
    [ -z "${POSTGRES_HOST}" ] || [ -z "${POSTGRES_PASSWORD}" ] || [ -z "${POSTGRES_USER}" ] \
    || [ -z "${SOLR_HTTP_ENDPOINT}" ] || [ -z "${SOLR_REPLICATION_FACTOR}" ] \
    || [ -z "${SOLR_NUM_SHARDS}" ] || [ -z "${GCLOUD_SQL_INSTANCE_NAME}" ]
) && echo missing infra connection details && exit 1

echo creating base dbs...
DB_PASSWORD=`python -c "import binascii,os;print(binascii.hexlify(os.urandom(12)))"`
DATASTORE_PASSWORD=`python -c "import binascii,os;print(binascii.hexlify(os.urandom(12)))"`
echo DB_PASSWORD="${DB_PASSWORD}"
echo DATASTORE_PASSWORD="${DATASTORE_PASSWORD}"

PGPASSWORD=$POSTGRES_PASSWORD create_db $POSTGRES_HOST $POSTGRES_USER $INSTANCE_ID $DB_PASSWORD &&\
PGPASSWORD=$POSTGRES_PASSWORD create_db_base $POSTGRES_HOST $POSTGRES_USER ${INSTANCE_ID}-datastore $DATASTORE_PASSWORD
[ "$?" != "0" ] && echo failed to create base dbs && exit 1

! curl -f "${SOLR_HTTP_ENDPOINT}/admin/collections?action=CREATE&name=${INSTANCE_ID}&collection.configName=${SOLRCLOUD_COLLECTION_CONFIG_NAME}&replicationFactor=${SOLR_REPLICATION_FACTOR}&numShards=${SOLR_NUM_SHARDS}" \
    && echo failed to create solr collection && exit 1

echo set permissions to cloud storage for import to sql

GCLOUD_SQL_SERVICE_ACCOUNT=`gcloud sql instances describe $GCLOUD_SQL_INSTANCE_NAME \
    | python3 -c "import sys,yaml; print(yaml.load(sys.stdin)['serviceAccountEmailAddress'])" | tee /dev/stderr`

gsutil acl ch -u ${GCLOUD_SQL_SERVICE_ACCOUNT}:R ${GCLOUD_SQL_DB_DUMP_URL}/ &&\
gsutil acl ch -u ${GCLOUD_SQL_SERVICE_ACCOUNT}:R ${GCLOUD_SQL_DATASTORE_DUMP_URL}/
[ "$?" != "0" ] && echo failed to setup google storage permissions for sql && exit 1

echo importing dbs to gcloud sql

! gcloud --project=$GCLOUD_SQL_PROJECT --quiet sql import sql "${GCLOUD_SQL_INSTANCE_NAME}" \
        "${GCLOUD_SQL_DB_DUMP_URL}" --database=$INSTANCE_ID --user=postgres \
    && echo failed to import db && exit 1
! gcloud --project=$GCLOUD_SQL_PROJECT --quiet sql import sql "${GCLOUD_SQL_INSTANCE_NAME}" \
        "${GCLOUD_SQL_DATASTORE_DUMP_URL}" --database="${INSTANCE_ID}-datastore" --user=postgres \
    && echo failed to import datastore db && exit 1

echo setting up datastore db permissions

DATASTORE_RO_USER="${INSTANCE_ID}-datastore-ro"
DATASTORE_RO_PASSWORD=`python -c "import binascii,os;print(binascii.hexlify(os.urandom(12)))"`

DS_RW_USER="${INSTANCE_ID}-datastore"

# these are exported as they are used by datastore-permissions.sql.template
export SITE_USER="${INSTANCE_ID}"
export DS_RO_USER="${DATASTORE_RO_USER}"

PGPASSWORD=$POSTGRES_PASSWORD psql -v ON_ERROR_STOP=on -h "${POSTGRES_HOST}" -U "${POSTGRES_USER}" -c "
    CREATE ROLE \"${DATASTORE_RO_USER}\" WITH LOGIN PASSWORD '${DATASTORE_RO_PASSWORD}' NOSUPERUSER NOCREATEDB NOCREATEROLE;
" &&\
PGPASSWORD=$POSTGRES_PASSWORD psql -v ON_ERROR_STOP=on -h "${POSTGRES_HOST}" -U "${POSTGRES_USER}" -d "${DS_RW_USER}" -c "
    REVOKE CREATE ON SCHEMA public FROM PUBLIC;
    REVOKE USAGE ON SCHEMA public FROM PUBLIC;
    GRANT CREATE ON SCHEMA public TO \"${SITE_USER}\";
    GRANT USAGE ON SCHEMA public TO \"${SITE_USER}\";
    GRANT CREATE ON SCHEMA public TO \"${DS_RW_USER}\";
    GRANT USAGE ON SCHEMA public TO \"${DS_RW_USER}\";
    GRANT \"${SITE_USER}\" TO \"${POSTGRES_USER}\";
    ALTER DATABASE \"${SITE_USER}\" OWNER TO ${POSTGRES_USER};
    ALTER DATABASE \"${DS_RW_USER}\" OWNER TO ${POSTGRES_USER};
    REVOKE CONNECT ON DATABASE \"${SITE_USER}\" FROM \"${DS_RO_USER}\";
    GRANT CONNECT ON DATABASE \"${DS_RW_USER}\" TO \"${DS_RO_USER}\";
    GRANT USAGE ON SCHEMA public TO \"${DS_RO_USER}\";
    ALTER DATABASE \"${SITE_USER}\" OWNER TO \"${SITE_USER}\";
    GRANT \"${DS_RW_USER}\" TO \"${POSTGRES_USER}\";
    ALTER DATABASE \"${DS_RW_USER}\" OWNER TO \"${DS_RW_USER}\";
" &&\
PGPASSWORD=$POSTGRES_PASSWORD psql -v ON_ERROR_STOP=on -h "${POSTGRES_HOST}" -U "${POSTGRES_USER}" -d "${DS_RW_USER}" -c "
    GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"${DS_RO_USER}\";
    ALTER DEFAULT PRIVILEGES FOR USER \"${DS_RW_USER}\" IN SCHEMA public GRANT SELECT ON TABLES TO \"${DS_RO_USER}\";
" &&\
bash ./templater.sh ./datastore-permissions.sql.template | grep ' OWNER TO ' -v \
    | PGPASSWORD=$POSTGRES_PASSWORD psql -v ON_ERROR_STOP=on -h "${POSTGRES_HOST}" -U "${POSTGRES_USER}" -d "${DS_RW_USER}"
[ "$?" != "0" ] && echo failed to set datastore db permissions && exit 1

echo Creating instance namespace

kubectl $KUBECTL_GLOBAL_ARGS create ns "${INSTANCE_NAMESPACE}" &&\
kubectl $KUBECTL_GLOBAL_ARGS --namespace "${INSTANCE_NAMESPACE}" \
    create serviceaccount "ckan-${INSTANCE_NAMESPACE}-operator" &&\
kubectl $KUBECTL_GLOBAL_ARGS --namespace "${INSTANCE_NAMESPACE}" \
    create role "ckan-${INSTANCE_NAMESPACE}-operator-role" \
                --verb list,get,create \
                --resource secrets,pods,pods/exec,pods/portforward &&\
kubectl $KUBECTL_GLOBAL_ARGS --namespace "${INSTANCE_NAMESPACE}" \
    create rolebinding "ckan-${INSTANCE_NAMESPACE}-operator-rolebinding" \
                       --role "ckan-${INSTANCE_NAMESPACE}-operator-role" \
                       --serviceaccount "${INSTANCE_NAMESPACE}:ckan-${INSTANCE_NAMESPACE}-operator"
[ "$?" != "0" ] && echo failed to create instance namespace && exit 1

echo Creating intsance envvars secret

# exporting these env vars as they will be replaced by python subprocess later
export CKAN_SQLALCHEMY_URL="postgresql://${INSTANCE_ID}:${DB_PASSWORD}@${POSTGRES_HOST}:5432/${INSTANCE_ID}"
export CKAN___BEAKER__SESSION__URL="postgresql://${INSTANCE_ID}:${DB_PASSWORD}@${POSTGRES_HOST}:5432/${INSTANCE_ID}"
export CKAN__DATASTORE__READ_URL="postgresql://${DATASTORE_RO_USER}:${DATASTORE_RO_PASSWORD}@${POSTGRES_HOST}:5432/${DS_RW_USER}"
export CKAN__DATASTORE__WRITE_URL="postgresql://${DS_RW_USER}:${DATASTORE_PASSWORD}@${POSTGRES_HOST}:5432/${DS_RW_USER}"
export CKAN_SOLR_URL="${SOLR_HTTP_ENDPOINT}/${INSTANCE_ID}"

echo "CKAN_SQLALCHEMY_URL=${CKAN_SQLALCHEMY_URL}"
echo "CKAN___BEAKER__SESSION__URL=${CKAN___BEAKER__SESSION__URL}"
echo "CKAN__DATASTORE__READ_URL=${CKAN__DATASTORE__READ_URL}"
echo "CKAN__DATASTORE__WRITE_URL=${CKAN__DATASTORE__WRITE_URL}"
echo "CKAN_SOLR_URL=${CKAN_SOLR_URL}"

cat $CKAN_VALUES_FILE | python3 -c '
import yaml, sys, base64, os
values = yaml.load(sys.stdin)
secrets = {
    "apiVersion": "v1",
    "kind": "Secret",
    "metadata": {
        "name": "ckan-envvars",
        "namespace": "'${INSTANCE_ID}'"
    },
    "type": "Opaque",
    "data": {}
}
for k, v in values.items():
    if k != "import":
        if k in ["CKAN_SQLALCHEMY_URL", "CKAN___BEAKER__SESSION__URL", "CKAN__DATASTORE__READ_URL",
                 "CKAN__DATASTORE__WRITE_URL", "CKAN_SOLR_URL"]:
            v = os.environ[k]
        secrets["data"][k] = base64.b64encode(v.encode()).decode()
print(yaml.dump(secrets, default_flow_style=False))
' | kubectl create -f -
[ "$?" != "0" ] && echo failed to create secret && exit 1

echo Deploying instance

echo '
apiVersion: apps/v1beta1
kind: Deployment
metadata:
  name: '${INSTANCE_ID}'
  namespace: '${INSTANCE_ID}'
spec:
  replicas: 1
  revisionHistoryLimit: 2
  template:
    metadata:
      labels:
        app: ckan
    spec:
      imagePullSecrets:
      - name: viderum-gitlab
      serviceAccountName: ckan-'${INSTANCE_ID}'-operator
      containers:
      - name: ckan
        image: '${CKAN_IMAGE}'
        envFrom:
        - secretRef:
            name: ckan-envvars
' | kubectl create -f -
[ "$?" != "0" ] && echo failed to deploy instance && exit 1

echo Great Success!
exit 0
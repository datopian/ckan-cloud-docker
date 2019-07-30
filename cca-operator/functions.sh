
get_secrets_json() {
    kubectl $KUBECTL_GLOBAL_ARGS get secret $1 -o json
}

get_secret_from_json() {
    local VAL=`echo "${1}" | jq -r ".data.${2}"`
    if [ "${VAL}" != "" ] && [ "${VAL}" != "null" ]; then
        echo "${VAL}" | base64 -d
    fi
}

# export the ckan env vars from the ckan env vars secret
export_ckan_env_vars() {
    ENV_VARS_SECRET="${1}"
    [ -z "${ENV_VARS_SECRET}" ] && return 0
    ! SECRETS_JSON=`get_secrets_json $ENV_VARS_SECRET` \
        && echo could not find ckan env vars secret ENV_VARS_SECRET && return 0
    export CKAN_APP_INSTANCE_UUID=`get_secret_from_json "${SECRETS_JSON}" CKAN_APP_INSTANCE_UUID`
    export CKAN_BEAKER_SESSION_SECRET=`get_secret_from_json "${SECRETS_JSON}" CKAN_BEAKER_SESSION_SECRET`
    export POSTGRES_PASSWORD=`get_secret_from_json "${SECRETS_JSON}" POSTGRES_PASSWORD`
    export POSTGRES_USER=`get_secret_from_json "${SECRETS_JSON}" POSTGRES_USER`
    export POSTGRES_HOST=`get_secret_from_json "${SECRETS_JSON}" POSTGRES_HOST`
    export POSTGRES_DB_NAME=`get_secret_from_json "${SECRETS_JSON}" POSTGRES_DB_NAME`
    export DATASTORE_POSTGRES_PASSWORD=`get_secret_from_json "${SECRETS_JSON}" DATASTORE_POSTGRES_PASSWORD`
    export DATASTORE_POSTGRES_USER=`get_secret_from_json "${SECRETS_JSON}" DATASTORE_POSTGRES_USER`
    export DATASTORE_RO_USER=`get_secret_from_json "${SECRETS_JSON}" DATASTORE_RO_USER`
    export DATASTORE_RO_PASSWORD=`get_secret_from_json "${SECRETS_JSON}" DATASTORE_RO_PASSWORD`
    export SOLR_URL=`get_secret_from_json "${SECRETS_JSON}" SOLR_URL`

    ( [ -z "${CKAN_BEAKER_SESSION_SECRET}" ] || [ -z "${CKAN_APP_INSTANCE_UUID}" ] || [ -z "${POSTGRES_PASSWORD}" ] || \
      [ -z "${POSTGRES_USER}" ] ) && echo missing required ckan env vars && return 1

    return 0
}

cluster_register_sub_domain() {
    CF_SUBDOMAIN="${1}"
    CF_HOSTNAME="${2}"
    CF_RECORD_NAME="${CF_SUBDOMAIN}${CF_RECORD_NAME_SUFFIX}"
    echo Setting CNAME from Cloudflare record ${CF_RECORD_NAME} to hostname ${CF_HOSTNAME}
    ( [ -z "${CF_AUTH_EMAIL}" ] || [ -z "${CF_AUTH_KEY}" ] || [ -z "${CF_ZONE_NAME}" ] ) \
        && echo missing CF_AUTH_EMAIL / CF_AUTH_KEY / CF_ZONE_NAME environment variables && return 1
    # '{"type":"CNAME","name":"{{CF_SUBDOMAIN}}","content":"{{CF_HOSTNAME}}","ttl":120,"proxied":false}'
    ( [ -z "${CF_ZONE_UPDATE_DATA_TEMPLATE}" ] ) \
        && echo missing CF_ZONE_UPDATE_DATA_TEMPLATE environment variable && return 1
    # '.ckan.io'
    ( [ -z "${CF_RECORD_NAME_SUFFIX}" ] ) \
        && echo missing CF_RECORD_NAME_SUFFIX environment variable && return 1
    CF_ZONE_ID=`curl -X GET "https://api.cloudflare.com/client/v4/zones" \
                     -H "X-Auth-Email: ${CF_AUTH_EMAIL}" \
                     -H "X-Auth-Key: ${CF_AUTH_KEY}" \
                     -H "Content-Type: application/json" \
                        | python3 -c "import json, sys; \
                                      zones = [zone['id'] for zone in json.load(sys.stdin)['result'] \
                                               if zone['name'] == '${CF_ZONE_NAME}']; \
                                      print(zones[0] if len(zones) > 0 else '')"`
    ( [ "$?" != "0" ] || [ -z "${CF_ZONE_ID}" ] ) \
        && echo Failed to get zone id for zone name ${CF_ZONE_NAME} && return 1
    CF_RECORD_ID=`curl -X GET "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records?name=${CF_RECORD_NAME}" \
                       -H "X-Auth-Email: ${CF_AUTH_EMAIL}" \
                       -H "X-Auth-Key: ${CF_AUTH_KEY}" \
                       -H "Content-Type: application/json" \
                            | python3 -c "import json, sys; \
                                          records = [record['id'] for record in json.load(sys.stdin)['result'] \
                                                     if record['name'] == '${CF_RECORD_NAME}']; \
                                          print(records[0] if len(records) > 0 else '')"`
    [ "$?" != "0" ] && echo Failed to get record id in zone name ${CF_ZONE_NAME} record name ${CF_RECORD_NAME} && return 1
    if [ -z "${CF_RECORD_ID}" ]; then
        ACTION="Created"
        echo Creating record name ${CF_RECORD_NAME} in zone name ${CF_ZONE_NAME}
        echo zone id = ${CF_ZONE_ID}
        TEMPFILE=`mktemp`
        echo "${CF_ZONE_UPDATE_DATA_TEMPLATE}" > $TEMPFILE
        export CF_SUBDOMAIN
        export CF_HOSTNAME
        UPDATE_SUCCESS=`curl -X POST \
                             "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records" \
                             -H "X-Auth-Email: ${CF_AUTH_EMAIL}" \
                             -H "X-Auth-Key: ${CF_AUTH_KEY}" \
                             -H "Content-Type: application/json" \
                             --data "$(./templater.sh $TEMPFILE)" \
                                | python3 -c "import json,sys; \
                                              print(json.load(sys.stdin)['success'])"`
    else
        ACTION="Updated"
        echo Updating record name ${CF_RECORD_NAME} in zone name ${CF_ZONE_NAME}
        echo zone id = ${CF_ZONE_ID}  record id = ${CF_RECORD_ID}
        TEMPFILE=`mktemp`
        echo "${CF_ZONE_UPDATE_DATA_TEMPLATE}" > $TEMPFILE
        export CF_SUBDOMAIN
        export CF_HOSTNAME
        UPDATE_SUCCESS=`curl -X PUT \
                             "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records/${CF_RECORD_ID}" \
                             -H "X-Auth-Email: ${CF_AUTH_EMAIL}" \
                             -H "X-Auth-Key: ${CF_AUTH_KEY}" \
                             -H "Content-Type: application/json" \
                             --data "$(./templater.sh $TEMPFILE)" \
                                | python3 -c "import json,sys; \
                                              print(json.load(sys.stdin)['success'])"`
    fi
    if [ "${UPDATE_SUCCESS}" == "True" ]; then
        echo Great Success!
        echo $ACTION DNS record ${CF_RECORD_NAME} with hostname ${CF_HOSTNAME}
        return 0
    else
        echo Failed to update record
        return 1
    fi
}

kubectl_init() {
    if ! [ -z "${KUBE_CONTEXT}" ]; then
        ! kubectl $KUBECTL_GLOBAL_ARGS config use-context "${KUBE_CONTEXT}" > /dev/stderr && echo failed to switch context > /dev/stderr && return 1
    fi
    return 0
}

cluster_management_init() {
    ! kubectl_init > /dev/stderr && return 1
    export INSTANCE_ID="${1}"
    [ -z "${INSTANCE_ID}" ] && echo missing INSTANCE_ID > /dev/stderr && return 1
    export INSTANCE_NAMESPACE="${INSTANCE_ID}"
    export CKAN_VALUES_FILE=/etc/ckan-cloud/${INSTANCE_ID}_values.yaml
    export CKAN_HELM_RELEASE_NAME="ckan-cloud-${INSTANCE_NAMESPACE}"
    return 0
}

instance_kubectl() {
    [ -z "${INSTANCE_NAMESPACE}" ] && echo missing INSTANCE_NAMESPACE > /dev/stderr && return 1
    kubectl $KUBECTL_GLOBAL_ARGS -n "${INSTANCE_NAMESPACE}" "$@"
}

instance_connection_info() {
    INSTANCE_ID="${1}"
    INSTANCE_NAMESPACE="${2}"
    INSTANCE_DOMAIN="${3}"
    CKAN_ADMIN_PASSWORD="${4}"
    if [ -z "${INSTANCE_DOMAIN}" ]; then
        echo Start port forwarding to access the instance:
        echo kubectl $KUBECTL_GLOBAL_ARGS -n ${INSTANCE_NAMESPACE} port-forward deployment/nginx 8080
        echo Add a hosts entry: "'127.0.0.1 nginx'"
        echo Access the instance at http://nginx:8080
    else
        echo CKAN Instance ${INSTANCE_ID} is available at https://${INSTANCE_DOMAIN}
    fi
    echo CKAN admin password: ${CKAN_ADMIN_PASSWORD}
}

instance_domain() {
    CKAN_VALUES_FILE="${1}"
    python3 -c 'import yaml; print(yaml.load(open("'${CKAN_VALUES_FILE}'")).get("domain", ""))'
}

add_domain_to_traefik() {
    export DOMAIN="${1}"
    export WITH_SANS_SSL="${2}"
    export INSTANCE_ID="${3}"
    export SERVICE_NAME="${4:-nginx}"
    export SERVICE_PORT="${5:-8080}"
    export SERVICE_NAMESPACE="${6:-${INSTANCE_ID}}"
    ( [ -z "${DOMAIN}" ] || [ -z "${INSTANCE_ID}" ] ) && echo missing required args && return 1
    ! python3 -c 'import toml' && python3 -m pip install --index-url ${PIP_INDEX_URL:-https://pypi.org/simple/} toml
    mkdir -p "/etc/ckan-cloud/backups/etc-traefik"
    BACKUP_FILE="/etc/ckan-cloud/backups/etc-traefik/`date +%Y%m%d%H%M%s`.yaml"
    kubectl $KUBECTL_GLOBAL_ARGS -n default get configmap etc-traefik -o yaml > $BACKUP_FILE &&\
    export TEMPFILE=`mktemp` &&\
    cat $BACKUP_FILE | python3 -c '
import sys, yaml, toml, os
conf = toml.loads(yaml.load(sys.stdin)["data"]["traefik.toml"])
domain = os.environ["DOMAIN"]
with_sans_ssl = os.environ["WITH_SANS_SSL"]
instance_id = os.environ["INSTANCE_ID"]
service_name = os.environ["SERVICE_NAME"]
service_port = os.environ["SERVICE_PORT"]
service_namespace = os.environ["SERVICE_NAMESPACE"]
for frontend_id, frontend in conf["frontends"].items():
    if frontend_id != instance_id:
        for route in frontend.get("routes", {}).values():
            if route.get("rule", "") == f"Host:{domain}":
                print(f"frontend rule already exists for domain {domain} under instance_id {frontend_id}", file=sys.stderr)
                exit(1)
conf["frontends"][instance_id] = {"backend": instance_id, "headers": {"SSLRedirect": True}, "passHostHeader": True,
                                  "routes": {"route1": {"rule": f"Host:{domain}"}}}
conf["backends"][instance_id] = {"servers": {"server1": {"url": f"http://{service_name}.{service_namespace}:{service_port}"}}}
if with_sans_ssl == "1":
    main_domain = conf["acme"]["domains"][0]["main"]
    assert domain.endswith(f".{main_domain}"), f"Invalid domain {domain} - must be subdomain of the main domain {main_domain}"
    if domain not in conf["acme"]["domains"][0]["sans"]:
      conf["acme"]["domains"][0]["sans"].append(domain)
print(toml.dumps(conf))
exit(0)' > $TEMPFILE &&\
    kubectl $KUBECTL_GLOBAL_ARGS delete configmap etc-traefik &&\
    kubectl $KUBECTL_GLOBAL_ARGS create configmap etc-traefik --from-file=traefik.toml=$TEMPFILE &&\
    rm $TEMPFILE &&\
    kubectl $KUBECTL_GLOBAL_ARGS patch deployment traefik -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}" &&\
    while ! kubectl $KUBECTL_GLOBAL_ARGS rollout status deployment traefik --watch=false; do echo . && sleep 5; done &&\
    [ "$?" != "0" ] && echo Failed to add domain to traefik && return 1
    return 0
}

generate_password() {
    python -c "import binascii,os;print(binascii.hexlify(os.urandom(${1:-12})))"
}

create_db_base() {
    local POSTGRES_HOST="${1}"
    local POSTGRES_USER="${2}"
    local CREATE_POSTGRES_USER="${3}"
    local CREATE_POSTGRES_PASSWORD="${4}"
    ( [ -z "${POSTGRES_HOST}" ] || [ -z "${POSTGRES_USER}" ] || [ -z "${CREATE_POSTGRES_USER}" ] || [ -z "${CREATE_POSTGRES_PASSWORD}" ] ) && return 1
    echo Initializing ${CREATE_POSTGRES_USER} on ${POSTGRES_HOST}
    psql -v ON_ERROR_STOP=on -h "${POSTGRES_HOST}" -U "${POSTGRES_USER}" -c "
        CREATE ROLE \"${CREATE_POSTGRES_USER}\" WITH LOGIN PASSWORD '${CREATE_POSTGRES_PASSWORD}' NOSUPERUSER NOCREATEDB NOCREATEROLE;
    " &&\
    psql -v ON_ERROR_STOP=on -h "${POSTGRES_HOST}" -U "${POSTGRES_USER}" -c "
        CREATE DATABASE \"${CREATE_POSTGRES_USER}\";
    " &&\
    echo DB initialized successfully && return 0
    echo DB Initialization failed && return 1
}

create_db() {
    local POSTGRES_HOST="${1}"
    local POSTGRES_USER="${2}"
    local CREATE_POSTGRES_USER="${3}"
    local CREATE_POSTGRES_PASSWORD="${4}"
    ! create_db_base "${POSTGRES_HOST}" "${POSTGRES_USER}" "${CREATE_POSTGRES_USER}" "${CREATE_POSTGRES_PASSWORD}" && return 1
    echo initializing postgis extensions &&\
    psql -v ON_ERROR_STOP=on -h "${POSTGRES_HOST}" -U "${POSTGRES_USER}" -d "${CREATE_POSTGRES_USER}" -c "
        CREATE EXTENSION IF NOT EXISTS postgis;
        CREATE EXTENSION IF NOT EXISTS postgis_topology;
        CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
        CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder;
    " &&\
    ckan_cloud_log '{"event":"ckan-db-initialized"}' &&\
    echo postgis extensions initialized successfully && return 0
    echo postgis extensions failed && return 1
}

create_datastore_db() {
    local POSTGRES_HOST="${1}"
    local POSTGRES_USER="${2}"
    local SITE_USER="${3}"
    local DS_RW_USER="${4}"
    local DS_RW_PASSWORD="${5}"
    local DS_RO_USER="${6}"
    local DS_RO_PASSWORD="${7}"
    ! create_db_base "${POSTGRES_HOST}" "${POSTGRES_USER}" "${DS_RW_USER}" "${DS_RW_PASSWORD}" && return 1
    ( [ -z "${SITE_USER}" ] || [ -z "${DS_RO_USER}" ] || [ -z "${DS_RO_PASSWORD}" ] ) && return 1
    echo Initializing datastore DB ${DS_RW_USER} on ${POSTGRES_HOST}
    export SITE_USER
    export DS_RW_USER
    export DS_RO_USER
    psql -v ON_ERROR_STOP=on -h "${POSTGRES_HOST}" -U "${POSTGRES_USER}" -c "
        CREATE ROLE \"${DS_RO_USER}\" WITH LOGIN PASSWORD '${DS_RO_PASSWORD}' NOSUPERUSER NOCREATEDB NOCREATEROLE;
    " &&\
    psql -v ON_ERROR_STOP=on -h "${POSTGRES_HOST}" -U "${POSTGRES_USER}" -d "${DS_RW_USER}" -c "
        REVOKE CREATE ON SCHEMA public FROM PUBLIC;
        REVOKE USAGE ON SCHEMA public FROM PUBLIC;
        GRANT CREATE ON SCHEMA public TO \"${SITE_USER}\";
        GRANT USAGE ON SCHEMA public TO \"${SITE_USER}\";
        GRANT CREATE ON SCHEMA public TO \"${DS_RW_USER}\";
        GRANT USAGE ON SCHEMA public TO \"${DS_RW_USER}\";
        ALTER DATABASE \"${SITE_USER}\" OWNER TO ${POSTGRES_USER};
        ALTER DATABASE \"${DS_RW_USER}\" OWNER TO ${POSTGRES_USER};
        REVOKE CONNECT ON DATABASE \"${SITE_USER}\" FROM \"${DS_RO_USER}\";
        GRANT CONNECT ON DATABASE \"${DS_RW_USER}\" TO \"${DS_RO_USER}\";
        GRANT USAGE ON SCHEMA public TO \"${DS_RO_USER}\";
        ALTER DATABASE \"${SITE_USER}\" OWNER TO \"${SITE_USER}\";
        ALTER DATABASE \"${DS_RW_USER}\" OWNER TO \"${DS_RW_USER}\";
    " &&\
    PGPASSWORD="${DS_RW_PASSWORD}" psql -v ON_ERROR_STOP=on -h "${POSTGRES_HOST}" -U "${DS_RW_USER}" -d "${DS_RW_USER}" -c "
        GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"${DS_RO_USER}\";
        ALTER DEFAULT PRIVILEGES FOR USER \"${DS_RW_USER}\" IN SCHEMA public GRANT SELECT ON TABLES TO \"${DS_RO_USER}\";
    " &&\
    bash ./templater.sh ./datastore-permissions.sql.template | grep ' OWNER TO ' -v \
        | PGPASSWORD="${DS_RW_PASSWORD}" psql -v ON_ERROR_STOP=on -h "${POSTGRES_HOST}" -U "${DS_RW_USER}" -d "${DS_RW_USER}" &&\
    ckan_cloud_log '{"event":"ckan-datastore-db-initialized"}' &&\
    echo Datastore DB initialized successfully && return 0
    echo Datastore DB initialization failed && return 1
}

ckan_cloud_log() {
    echo "--START_CKAN_CLOUD_LOG--$(echo "${1}" | jq -Mc .)--END_CKAN_CLOUD_LOG--" > /dev/stderr
}

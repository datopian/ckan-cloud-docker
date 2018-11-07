CF_ZONE_UPDATE_DATA_TEMPLATE='{"type":"CNAME","name":"{{CF_SUBDOMAIN}}","content":"{{CF_HOSTNAME}}","ttl":120,"proxied":false}'
CF_RECORD_NAME_SUFFIX=".ckan.io"

get_secrets_json() {
    kubectl get secret $1 -o json
}

get_secret_from_json() {
    VAL=`echo "${1}" | jq -r ".data.${2}"`
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
    export DATASTORE_POSTGRES_PASSWORD=`get_secret_from_json "${SECRETS_JSON}" DATASTORE_POSTGRES_PASSWORD`
    export DATASTORE_POSTGRES_USER=`get_secret_from_json "${SECRETS_JSON}" DATASTORE_POSTGRES_USER`
    export DATASTORE_RO_USER=`get_secret_from_json "${SECRETS_JSON}" DATASTORE_RO_USER`
    export DATASTORE_RO_PASSWORD=`get_secret_from_json "${SECRETS_JSON}" DATASTORE_RO_PASSWORD`

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

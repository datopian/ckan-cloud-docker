#!/usr/bin/env bash

[ "${1}" == "--help" ] && echo ./update-instance.sh '<INSTANCE_ID>' && exit 0

source functions.sh
! cluster_management_init "${1}" && exit 1

! [ -e "${CKAN_VALUES_FILE}" ] && echo missing ${CKAN_VALUES_FILE} && exit 1

echo Creating instance: ${INSTANCE_ID}

INSTANCE_DOMAIN=`python3 -c '
import yaml;
print(yaml.load(open("'${CKAN_VALUES_FILE}'")).get("domain", ""))
' 2>/dev/null`

CKAN_ADMIN_EMAIL=`python3 -c '
import yaml;
print(yaml.load(open("'${CKAN_VALUES_FILE}'")).get("ckanAdminEmail", "admin@${INSTANCE_ID}"))
'`

WITH_SANS_SSL=`python3 -c '
import yaml;
print("1" if yaml.load(open("'${CKAN_VALUES_FILE}'")).get("withSansSSL", False) else "0")
' 2>/dev/null`

REGISTER_SUBDOMAIN=`python3 -c '
import yaml;
print(yaml.load(open("'${CKAN_VALUES_FILE}'")).get("registerSubdomain", ""))
' 2>/dev/null`

CKAN_HELM_CHART_REPO=`python3 -c '
import yaml;
print(yaml.load(open("'${CKAN_VALUES_FILE}'")).get("ckanHelmChartRepo", "https://raw.githubusercontent.com/ViderumGlobal/ckan-cloud-helm/master/charts_repository"))
' 2>/dev/null`

CKAN_HELM_CHART_VERSION=`python3 -c '
import yaml;
print(yaml.load(open("'${CKAN_VALUES_FILE}'")).get("ckanHelmChartVersion", ""))
' 2>/dev/null`

USE_CENTRALIZED_INFRA=`python3 -c '
import yaml;
print("1" if yaml.load(open("'${CKAN_VALUES_FILE}'")).get("useCentralizedInfra", False) else "0")
' 2>/dev/null`

LOAD_BALANCER_HOSTNAME=$(kubectl $KUBECTL_GLOBAL_ARGS -n default get service traefik -o yaml \
    | python3 -c 'import sys, yaml; print(yaml.load(sys.stdin)["status"]["loadBalancer"]["ingress"][0]["hostname"])' 2>/dev/null)

if [ "${REGISTER_SUBDOMAIN}" != "" ]; then
    cluster_register_sub_domain "${REGISTER_SUBDOMAIN}" "${LOAD_BALANCER_HOSTNAME}"
    [ "$?" != "0" ] && exit 1
fi

if ! [ -z "${INSTANCE_DOMAIN}" ]; then
    ! add_domain_to_traefik "${INSTANCE_DOMAIN}" "${WITH_SANS_SSL}" "${INSTANCE_ID}" && exit 1
fi

if kubectl $KUBECTL_GLOBAL_ARGS get ns "${INSTANCE_NAMESPACE}"; then
    IS_NEW_NAMESPACE=0
    echo Namespace exists: ${INSTANCE_NAMESPACE}
    echo skipping RBAC creation
else
    IS_NEW_NAMESPACE=1
    echo Creating namespace: ${INSTANCE_NAMESPACE}

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
    [ "$?" != "0" ] && exit 1
fi

if [ "${USE_CENTRALIZED_INFRA}" == "1" ]; then
    echo initializing centralized infrastructure
    echo Verifying ckan-infra secret on namespace ${INSTANCE_NAMESPACE}
    if ! kubectl $KUBECTL_GLOBAL_ARGS --namespace "${INSTANCE_NAMESPACE}" get secret ckan-infra; then
        echo creating ckan-infra secret
        kubectl $KUBECTL_GLOBAL_ARGS -n ckan-cloud get secret ckan-infra --export -o yaml \
            | kubectl $KUBECTL_GLOBAL_ARGS --namespace "${INSTANCE_NAMESPACE}" create -f -
        [ "$?" != "0" ] && exit 1
    fi
    ! SOLRCLOUD_POD_NAME=$(kubectl -n ckan-cloud get pods -l "app=solr" --field-selector 'status.phase=Running' -o 'jsonpath={.items[0].metadata.name}') && exit 1
    echo Verifying solrcloud collection ${INSTANCE_NAMESPACE} on solrcloud pod $SOLRCLOUD_POD_NAME in namespace ckan-cloud
    SOLRCLOUD_COLLECTION_EXISTS=$(kubectl -n ckan-cloud exec $SOLRCLOUD_POD_NAME \
                                    -- curl 'localhost:8983/solr/admin/collections?action=LIST&wt=json' \
                                    | python3 -c 'import json,sys; print("1" if ("'${INSTANCE_NAMESPACE}'" \
                                                                         in json.load(sys.stdin)["collections"]) \
                                                                         else "0")')
    if [ "${SOLRCLOUD_COLLECTION_EXISTS}" == "0" ]; then
        echo creating solrcloud collection
        kubectl -n ckan-cloud exec $SOLRCLOUD_POD_NAME -- \
            sudo -u solr bin/solr create_collection -c ${INSTANCE_NAMESPACE} -d ckan_default -n ckan_default
        [ "$?" != "0" ] && exit 1
    fi
    echo centralized infrastructure initialized successfully
fi

echo Deploying CKAN instance: ${INSTSANCE_ID}

echo Initializing ckan-cloud Helm repo "${CKAN_HELM_CHART_REPO}"
helm init --client-only &&\
helm repo add ckan-cloud "${CKAN_HELM_CHART_REPO}"
[ "$?" != "0" ] && exit 1

helm_upgrade() {
    if [ -z "${CKAN_HELM_CHART_VERSION}" ]; then
        echo Using latest stable ckan chart
        VERSIONARGS=""
    else
        echo Using ckan chart version ${CKAN_HELM_CHART_VERSION}
        VERSIONARGS=" --version ${CKAN_HELM_CHART_VERSION} "
    fi
    helm --namespace "${INSTANCE_NAMESPACE}" upgrade "${CKAN_HELM_RELEASE_NAME}" ckan-cloud/ckan \
        -if "${CKAN_VALUES_FILE}" "$@" --dry-run --debug > /dev/stderr $VERSIONARGS &&\
    helm --namespace "${INSTANCE_NAMESPACE}" upgrade "${CKAN_HELM_RELEASE_NAME}" ckan-cloud/ckan \
        -if "${CKAN_VALUES_FILE}" $VERSIONARGS "$@"
}

check_instance_status() {
    local check_create_status="${1}"
    ./instance-status.sh "${INSTANCE_ID}" | python3 -c '
import yaml, json, sys

check_create_status = ("'${check_create_status}'" == "1")
status, metadata = list(yaml.load_all(sys.stdin))

errors = []
ckan_cloud_logs = []
ckan_cloud_events = set()
pod_names = []
for app, app_status in status.items():
    for kind, kind_items in app_status.items():
        for item in kind_items:
            for error in item.get("errors", []):
                errors.append(dict(error, kind=kind, app=app, name=item.get("name")))
            for logdata in item.get("ckan-cloud-logs", []):
                ckan_cloud_logs.append(dict(logdata, kind=kind, app=app, name=item.get("name")))
                if "event" in logdata:
                    ckan_cloud_events.add(logdata["event"])
            if kind == "pods":
                pod_names.append(item["name"])

if check_create_status:
    expected_events = set(["ckan-env-vars-created", "ckan-secrets-created", "got-ckan-secrets", "ckan-db-initialized",
                           "ckan-datastore-db-initialized", "ckan-entrypoint-initialized", "ckan-entrypoint-db-init-success",
                           "ckan-entrypoint-extra-init-success"])
else:
    expected_events = set(["ckan-env-vars-exists", "ckan-secrets-exists", "got-ckan-secrets",
                           "ckan-entrypoint-initialized", "ckan-entrypoint-db-init-success", "ckan-entrypoint-extra-init-success"])
missing_events = expected_events.difference(ckan_cloud_events)

print(yaml.dump(metadata, default_flow_style=False))
print("## pod names")
print(yaml.dump(pod_names, default_flow_style=False))
print("## errors")
print(yaml.dump(errors, default_flow_style=False))
print("## ckan_cloud_logs")
print(yaml.dump(ckan_cloud_logs, default_flow_style=False))
print("## missing events")
print(list(missing_events))

exit(0 if len(errors) == 0 and len(missing_events) == 0 else 1)'
}

wait_for_instance_status() {
    local delay_seconds=15
    local timeout_seconds=600
    local check_create_status="${1}"
    if [ "${check_create_status}" == "1" ]; then
        echo waiting for create instance status
    else
        echo waiting for existing instance status
    fi
    echo delay_seconds=$delay_seconds timeout_seconds=$timeout_seconds
    SECONDS=0
    while true; do
        expr $SECONDS '>' $timeout_seconds >/dev/null && echo timed out && return 1
        sleep $delay_seconds
        check_instance_status "${check_create_status}" && return 0
    done
    echo unexpected failure && return 1
}

if [ "${IS_NEW_NAMESPACE}" == "1" ]; then
    helm_upgrade --set replicas=1 --set nginxReplicas=1 --set disableJobs=true --set noProbes=true &&\
    wait_for_instance_status "1" &&\
    ./instance-status.sh "${INSTANCE_ID}"
    [ "$?" != "0" ] && exit 1
fi

helm_upgrade && wait_for_instance_status "0" && ./instance-status.sh "${INSTANCE_ID}"
[ "$?" != "0" ] && exit 1

CKAN_POD_NAME=$(kubectl $KUBECTL_GLOBAL_ARGS -n ${INSTANCE_NAMESPACE} get pods -l "app=ckan" -o 'jsonpath={.items[0].metadata.name}')
echo CKAN_POD_NAME = "${CKAN_POD_NAME}" > /dev/stderr

if kubectl $KUBECTL_GLOBAL_ARGS -n "${INSTANCE_NAMESPACE}" get secret ckan-admin-password; then
    echo getting ckan admin password from existing secret
    CKAN_ADMIN_PASSWORD=$( \
        get_secret_from_json "$(kubectl $KUBECTL_GLOBAL_ARGS -n "${INSTANCE_NAMESPACE}" get secret ckan-admin-password -o json)" \
        "CKAN_ADMIN_PASSWORD" \
    )
else
    echo creating ckan admin user
    CKAN_ADMIN_PASSWORD=$(python3 -c "import binascii,os;print(binascii.hexlify(os.urandom(12)).decode())")
    echo y \
        | kubectl $KUBECTL_GLOBAL_ARGS -n ${INSTANCE_NAMESPACE} exec -it ${CKAN_POD_NAME} -- bash -c \
            "ckan-paster --plugin=ckan sysadmin -c /etc/ckan/production.ini add admin password=${CKAN_ADMIN_PASSWORD} email=${CKAN_ADMIN_EMAIL}" \
                > /dev/stderr &&\
    kubectl $KUBECTL_GLOBAL_ARGS -n "${INSTANCE_NAMESPACE}" \
        create secret generic ckan-admin-password "--from-literal=CKAN_ADMIN_PASSWORD=${CKAN_ADMIN_PASSWORD}"
    [ "$?" != "0" ] && exit 1
fi

# Force traefik update to ensure route is connected
kubectl $KUBECTL_GLOBAL_ARGS -n default patch deployment traefik -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"

# skip sanity test for now as it causes some problems
# if ! [ -z "${INSTANCE_DOMAIN}" ]; then
#     echo Running sanity tests for CKAN instance ${INSTSANCE_ID} on domain ${INSTANCE_DOMAIN}
#     if [ "$(curl https://${INSTANCE_DOMAIN}/api/3)" != '{"version": 3}' ]; then
#         kubectl $KUBECTL_GLOBAL_ARGS -n default patch deployment traefik \
#             -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}" &&\
#         kubectl $KUBECTL_GLOBAL_ARGS -n default rollout status deployment traefik &&\
#         sleep 10 &&\
#         [ "$(curl https://${INSTANCE_DOMAIN}/api/3)" != '{"version": 3}' ]
#         [ "$?" != "0" ] && exit 1
#     fi
# fi

echo Great Success!
echo CKAN Instance ${INSTANCE_ID} is ready
instance_connection_info "${INSTANCE_ID}" "${INSTANCE_NAMESPACE}" "${INSTANCE_DOMAIN}" "${CKAN_ADMIN_PASSWORD}"

exit 0

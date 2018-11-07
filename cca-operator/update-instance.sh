#!/usr/bin/env bash

INSTANCE_ID="${1}"

[ -z "${INSTANCE_ID}" ] && exit 1

INSTANCE_NAMESPACE="${INSTANCE_ID}"
export KUBECONFIG=/etc/ckan-cloud/.kube-config

CKAN_VALUES_FILE=/etc/ckan-cloud/${INSTANCE_ID}_values.yaml
TRAEFIK_VALUES_FILE=/etc/ckan-cloud/traefik-values.yaml
TRAEFIK_HELM_CHART_PATH=/etc/ckan-cloud/datagov-ckan-multi/multi-tenant-cluster/traefik
TRAEFIK_HELM_RELEASE_NAME=traefik
TRAEFIK_NAMESPACE=default
CKAN_HELM_RELEASE_NAME="ckan-multi-${INSTANCE_NAMESPACE}"
CKAN_HELM_CHART_PATH=/etc/ckan-cloud/datagov-ckan-multi/multi-tenant-helm/ckan
CREATE_PULL_SECRET_SCRIPT=/etc/ckan-cloud/.create-pull-secret.sh

! [ -e "${CKAN_VALUES_FILE}" ] && echo missing ${CKAN_VALUES_FILE} && exit 1
! [ -e "${TRAEFIK_VALUES_FILE}" ] && echo missing ${TRAEFIK_VALUES_FILE} && exit 1
! [ -e "${TRAEFIK_HELM_CHART_PATH}" ] && echo missing ${TRAEFIK_HELM_CHART_PATH} && exit 1
! [ -e "${CKAN_HELM_CHART_PATH}" ] && echo missing ${CKAN_HELM_CHART_PATH} && exit 1
! [ -e "${CREATE_PULL_SECRET_SCRIPT}" ] && echo missing ${CREATE_PULL_SECRET_SCRIPT} && exit 1

echo Deploying CKAN instance: ${INSTSANCE_ID}

helm_upgrade() {
    helm --namespace "${INSTANCE_NAMESPACE}" upgrade "${CKAN_HELM_RELEASE_NAME}" "${CKAN_HELM_CHART_PATH}" \
        -if "${CKAN_VALUES_FILE}" "$@" --dry-run --debug > /dev/stderr &&\
    helm --namespace "${INSTANCE_NAMESPACE}" upgrade "${CKAN_HELM_RELEASE_NAME}" "${CKAN_HELM_CHART_PATH}" \
        -if "${CKAN_VALUES_FILE}" "$@"
}

wait_for_pods() {
    while ! kubectl --namespace "${INSTANCE_NAMESPACE}" get pods -o yaml | python3 -c '
import yaml, sys;
for pod in yaml.load(sys.stdin)["items"]:
    if pod["status"]["phase"] != "Running":
        print(pod["metadata"]["name"] + ": " + pod["status"]["phase"])
        exit(1)
    elif not pod["status"]["containerStatuses"][0]["ready"]:
        print(pod["metadata"]["name"] + ": ckan container is not ready")
        exit(1)
exit(0)
    '; do
        sleep 2
    done &&\
    kubectl --namespace "${INSTANCE_NAMESPACE}" get pods
}

helm_upgrade &&\
sleep 1 &&\
wait_for_pods &&\
exit 0

exit 1

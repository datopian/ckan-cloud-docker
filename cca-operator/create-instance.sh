#!/usr/bin/env bash

[ "${1}" == "--help" ] && echo ./create-instance.sh '<INSTANCE_ID>' && exit 0

source functions.sh
! cluster_management_init "${1}" && exit 1

INSTANCE_ID="${1}"
[ -z "${INSTANCE_ID}" ] && exit 1
INSTANCE_NAMESPACE="${INSTANCE_ID}"
CKAN_HELM_RELEASE_NAME="ckan-cloud-${INSTANCE_NAMESPACE}"

kubectl $KUBECTL_GLOBAL_ARGS get ns "${INSTANCE_NAMESPACE}" && echo namespace ${INSTANCE_NAMESPACE} already exists && exit 1
helm status $CKAN_HELM_RELEASE_NAME && echo Helm release ${CKAN_HELM_RELEASE_NAME} already exists && exit 1

exec ./update-instance.sh "$@"
#!/usr/bin/env bash

[ "${1}" == "--help" ] && echo ./delete-instance.sh '<INSTANCE_ID>' && exit 0

source functions.sh
! cluster_management_init "${1}" && exit 1

if kubectl $KUBECTL_GLOBAL_ARGS get ns "${INSTANCE_NAMESPACE}"; then
    echo Deleting instance namespace: ${INSTANCE_NAMESPACE}

    ! kubectl $KUBECTL_GLOBAL_ARGS -n ${INSTANCE_NAMESPACE} delete deployment ckan jobs && echo WARNING: failed to delete ckan pods
    ! kubectl $KUBECTL_GLOBAL_ARGS delete ns "${INSTANCE_NAMESPACE}" && echo WARNING: failed to delete instance namespace

    echo WARNING! instance was not removed from the load balancer

    echo Instance namespace ${INSTANCE_NAMESPACE} deleted
else
    echo Instance namespace does not exist: ${INSTANCE_NAMESPACE}
fi

if helm status $CKAN_HELM_RELEASE_NAME; then
    ! helm delete --purge "${CKAN_HELM_RELEASE_NAME}" && exit 1
else
    echo Helm release does not exist: ${CKAN_HELM_RELEASE_NAME}
fi

echo Instance deleted successfully: ${INSTANCE_ID}
exit 0

#!/usr/bin/env bash

[ "${1}" == "--help" ] && echo ./delete-instance.sh '<INSTANCE_ID>' && exit 0

source functions.sh
! cluster_management_init "${1}" && exit 1

if kubectl $KUBECTL_GLOBAL_ARGS get ns "${INSTANCE_NAMESPACE}"; then
    echo Deleting instance namespace: ${INSTANCE_NAMESPACE}

    ! kubectl $KUBECTL_GLOBAL_ARGS -n ${INSTANCE_NAMESPACE} delete deployment ckan jobs --wait=false && echo WARNING: failed to delete ckan pods
    echo waiting 60 seconds to let ckan pods stop
    sleep 60
    ! kubectl $KUBECTL_GLOBAL_ARGS delete ns "${INSTANCE_NAMESPACE}" --wait=false && echo WARNING: failed to delete instance namespace
    echo waiting 60 seconds to let namespace terminate
    echo waiting for all pods to be removed from namespace
    while [ "$(kubectl get pods -n "${INSTANCE_NAMESPACE}" --no-headers | tee /dev/stderr | wc -l)" != "0" ]; do
        sleep 5
        echo .
    done

    echo WARNING! instance was not removed from the load balancer

    echo Instance namespace ${INSTANCE_NAMESPACE} terminated successfully
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

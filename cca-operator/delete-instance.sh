#!/usr/bin/env bash

INSTANCE_ID="${1}"

[ -z "${INSTANCE_ID}" ] && exit 1

INSTANCE_NAMESPACE="${INSTANCE_ID}"
export KUBECONFIG=/etc/ckan-cloud/.kube-config

echo Deleting instance namespace: ${INSTANCE_NAMESPACE}

kubectl -n ${INSTANCE_NAMESPACE} delete deployment ckan jobs &&\
sleep 30 &&\
kubectl delete ns "${INSTANCE_NAMESPACE}"
[ "$?" != "0" ] && exit 1

echo WARNING! instance was not removed from the load balancer

echo Instance namespace ${INSTANCE_NAMESPACE} deleted successfully
exit 0

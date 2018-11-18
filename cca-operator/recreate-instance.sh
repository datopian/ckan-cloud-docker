#!/usr/bin/env bash

[ "${1}" == "--help" ] && echo ./recreate-instance.sh '<INSTANCE_ID>' && exit 0

source functions.sh
! kubectl_init && exit 1

INSTANCE_ID="${1}"
[ -z "${INSTANCE_ID}" ] && exit 1
INSTANCE_NAMESPACE="${INSTANCE_ID}"

./delete-instance.sh "${INSTANCE_ID}" &&\
while kubectl $KUBECTL_GLOBAL_ARGS get ns "${INSTANCE_NAMESPACE}"; do
    echo .
    sleep 2
done &&\
./create-instance.sh "${INSTANCE_ID}"

#!/usr/bin/env bash

[ "${1}" == "--help" ] && echo ./instance-connection-info.sh '<INSTANCE_ID>' && exit 0

source functions.sh
! cluster_management_init "${1}" && exit 1

CKAN_ADMIN_PASSWORD=$( \
    get_secret_from_json "$(kubectl $KUBECTL_GLOBAL_ARGS -n "${INSTANCE_NAMESPACE}" get secret ckan-admin-password -o json)" \
    "CKAN_ADMIN_PASSWORD" \
)

instance_connection_info "${INSTANCE_ID}" "${INSTANCE_NAMESPACE}" "$(instance_domain $CKAN_VALUES_FILE)" "${CKAN_ADMIN_PASSWORD}"

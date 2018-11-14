#!/usr/bin/env bash

[ "${1}" == "--help" ] && echo ./get-instance-values.sh '<INSTANCE_ID>' && exit 0

source functions.sh
! cluster_management_init "${1}" >/dev/null 2>&1 && exit 1

! [ -e "${CKAN_VALUES_FILE}" ] && echo missinsg values file: ${CKAN_VALUES_FILES} && exit 1

cat "${CKAN_VALUES_FILE}"

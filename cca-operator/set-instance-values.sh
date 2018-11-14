#!/usr/bin/env bash

[ "${1}" == "--help" ] && echo cat values.yaml '|' ./set-instance-values.sh '<INSTANCE_ID>' && exit 0

source functions.sh
! cluster_management_init "${1}" && exit 1

if [ -e "${CKAN_VALUES_FILE}" ]; then
    mkdir -p "/etc/ckan-cloud/backups/${INSTANCE_ID}/values"
    ! mv "${CKAN_VALUES_FILE}" "/etc/ckan-cloud/backups/${INSTANCE_ID}/values/`date +%Y%m%d%H%M%s`.yaml" && exit 1
fi

! cat > "${CKAN_VALUES_FILE}" && echo failed to set instance values && exit 1

echo Stored values for instance ${INSTANCE_ID}
exit 0

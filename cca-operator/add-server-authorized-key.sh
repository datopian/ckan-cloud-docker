#!/usr/bin/env bash

[ "${1}" == "--help" ] && echo cat ~/.ssh/id_rsa.pub '|' ./add-server-authorized-key.sh && exit 0

CCA_OPERATOR_ROLE="${1}"

echo Adding authorized key $(! [ -z "${CCA_OPERATOR_ROLE}" ] && echo with limited role: $CCA_OPERATOR_ROLE)

mkdir -p /etc/ckan-cloud/cca-operator && chmod 700 /etc/ckan-cloud && chmod 700 /etc/ckan-cloud/cca-operator && \
if [ -z "${CCA_OPERATOR_ROLE}" ]; then
    cat
else
    echo 'command="export CCA_OPERATOR_ROLE='${CCA_OPERATOR_ROLE}'; ./cca-operator.sh ./cca-operator.py \"${SSH_ORIGINAL_COMMAND}\""' $(cat)
fi >> /etc/ckan-cloud/cca-operator/sshd_authorized_keys
[ "$?" != "0" ] && exit 1

echo Added authorized key, restart cca-operator server for this change to take effect
exit 0

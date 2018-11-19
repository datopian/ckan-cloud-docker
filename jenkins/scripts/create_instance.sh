#!/usr/bin/env bash

if ! [ -z "${VALUES}" ];  then
    ! echo "${VALUES}" | tee /dev/stderr | /etc/ckan-cloud/cca_operator.sh ./set-instance-values.sh ${INSTANCE_ID} && exit 1
fi

/etc/ckan-cloud/cca_operator.sh ./create-instance.sh ${INSTANCE_ID}

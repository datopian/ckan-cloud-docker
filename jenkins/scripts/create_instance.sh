#!/usr/bin/env bash

echo "${VALUES}" | tee /dev/stdout | /etc/ckan-cloud/cca_operator.sh ./set-instance-values.sh ${INSTANCE_ID} &&\
/etc/ckan-cloud/cca_operator.sh ./create-instance.sh ${INSTANCE_ID}

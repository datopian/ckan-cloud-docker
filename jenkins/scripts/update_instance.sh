#!/usr/bin/env bash

VALUES_TEMPFILE=`mktemp`
export QUIET=1
! /etc/ckan-cloud/cca_operator.sh ./get-instance-values.sh "${INSTANCE_ID}" > $VALUES_TEMPFILE \
    && echo failed to get instance values && exit 1
export QUIET=0

TEMPFILE=`mktemp` &&\
echo "${UPDATE_VALUES}" \
  | python3 -c '
import yaml,sys;
values = yaml.load(open("'${VALUES_TEMPFILE}'"))
values.update(**yaml.load(sys.stdin))
print(yaml.dump(values, default_flow_style=False, allow_unicode=True))
' > $TEMPFILE &&\
cat $TEMPFILE | tee /dev/stderr | /etc/ckan-cloud/cca_operator.sh ./set-instance-values.sh ${INSTANCE_ID} &&\
/etc/ckan-cloud/cca_operator.sh ${UPDATE_INSTANCE_COMMAND:-./update-instance.sh} ${INSTANCE_ID}

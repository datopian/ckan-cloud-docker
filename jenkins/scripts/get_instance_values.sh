#!/usr/bin/env bash

export QUIET=1
/etc/ckan-cloud/cca_operator.sh ./get-instance-values.sh "${INSTANCE_ID}" \
  | python3 -c "
import yaml, sys;
print(yaml.dump(yaml.load(sys.stdin), default_flow_style=False, indent=2, width=99999, allow_unicode=True))
"

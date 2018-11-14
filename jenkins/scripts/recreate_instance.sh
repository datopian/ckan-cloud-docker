#!/usr/bin/env bash

export UPDATE_INSTANCE_COMMAND=./recreate-instance.sh
exec jenkins/scripts/update_instance.sh "$@"

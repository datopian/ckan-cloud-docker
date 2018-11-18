#!/usr/bin/env bash

[ "${1}" == "--help" ] && echo ./kubectl.sh '[kubectl args..]' && exit 0

source functions.sh
! kubectl_init >/dev/null 2>&1 && exit 1

exec kubectl $KUBECTL_GLOBAL_ARGS "$@"

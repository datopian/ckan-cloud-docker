#!/usr/bin/env bash

source cicd_functions.sh

if [ "${1}" == "install" ]; then
    ! pull_latest_images && exit 1
    exit 0

elif [ "${1}" == "script" ]; then
    ! (build_latest_images) && exit 1
    exit 0

elif [ "${1}" == "deploy" ]; then
    ! (tag_images "${TRAVIS_COMMIT}" && push_images "${TRAVIS_COMMIT}" && print_summary "${TRAVIS_COMMIT}") && exit 1
    exit 0

fi

echo unexpected failure
exit 1

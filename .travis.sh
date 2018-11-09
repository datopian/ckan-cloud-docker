#!/usr/bin/env bash

source cicd_functions.sh

if [ "${1}" == "install" ]; then
    ! pull_latest_images && exit 1
    exit 0

elif [ "${1}" == "script" ]; then
    ! (build_latest_images) && exit 1
    exit 0

elif [ "${1}" == "deploy" ]; then
    TAG="${TRAVIS_TAG:-TRAVIS_COMMIT}"
    ! tag_images "${TAG}" && exit 1
    if [ "${TRAVIS_BRANCH}" == "master" ]; then
        ! push_latest_images && exit 1
    fi
    ! push_tag_images "${TAG}" && exit 1
    print_summary "${TAG}"
    exit 0

fi

echo unexpected failure
exit 1

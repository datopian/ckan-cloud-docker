#!/usr/bin/env bash

source cicd_functions.sh

if [ "${1}" == "install" ]; then
    ! pull_latest_images && exit 1
    exit 0

elif [ "${1}" == "script" ]; then
    ! (build_latest_images) && exit 1
    ! docker build -t viderum/ckan-theme-generator:latest ckan/themer && exit 1
    exit 0

elif [ "${1}" == "deploy" ]; then
    TAG="${TRAVIS_TAG:-${TRAVIS_COMMIT}}"
    ! tag_images "${TAG}" && exit 1
    if [ "${TRAVIS_BRANCH}" == "master" ]; then
        ! push_latest_images && exit 1
        ! docker push viderum/ckan-theme-generator:latest && exit 1
        PUSHED_LATEST=1
    else
        PUSHED_LATEST=0
    fi
    ! push_tag_images "${TAG}" && exit 1
    print_summary "${TAG}" "${PUSHED_LATEST}"
    if [ "${TRAVIS_TAG}" != "" ]; then
        if ! [ -z "${SLACK_TAG_NOTIFICATION_CHANNEL}" ] && ! [ -z "${SLACK_TAG_NOTIFICATION_WEBHOOK_URL}" ]; then
            ! curl -X POST \
                   --data-urlencode "payload={\"channel\": \"#${SLACK_TAG_NOTIFICATION_CHANNEL}\", \"username\": \"CKAN Cloud\", \"text\": \"Released ckan-cloud-docker ${TAG}\nhttps://github.com/ViderumGlobal/ckan-cloud-docker/releases/tag/${TAG}\", \"icon_emoji\": \":female-technologist:\"}" \
                   ${SLACK_TAG_NOTIFICATION_WEBHOOK_URL} && exit 1
        fi
    fi
    exit 0

fi

echo unexpected failure
exit 1

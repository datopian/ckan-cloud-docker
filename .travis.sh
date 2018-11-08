#!/usr/bin/env bash

DOCKER_IMAGE=viderum/ckan-cloud-docker

APPS="ckan cca-operator nginx db solr"

if [ "${1}" == "install" ]; then
    exit 0

elif [ "${1}" == "script" ]; then
    for APP in $APPS; do
        LATEST_IMAGE="${DOCKER_IMAGE}:${APP}-latest"
        TAG_IMAGE="${DOCKER_IMAGE}:${APP}-${TRAVIS_COMMIT}"
        docker pull $LATEST_IMAGE
        if [ "${APP}" == "cca-operator" ]; then
            docker build --cache-from "${LATEST_IMAGE}" \
                         -t "${LATEST_IMAGE}" \
                         -t "${TAG_IMAGE}" \
                         cca-operator
            [ "$?" != "0" ] && exit 1
        else
            echo "version: '3.2'
services:
  ${APP}:
    build:
      cache_from:
      - ${LATEST_IMAGE}" > /tmp/docker-compose-cache-override.yaml
            docker-compose -f docker-compose.yaml -f /tmp/docker-compose-cache-override.yaml build $APP &&\
            docker tag ckan-multi-$APP "${LATEST_IMAGE}" &&\
            docker tag ckan-multi-$APP "${TAG_IMAGE}"
            [ "$?" != "0" ] && exit 1
            if [ "${APP}" == "ckan" ]; then
                for DOCKER_COMPOSE_OVERRIDE in `ls .docker-compose.*.yaml`; do
                    OVERRIDE_NAME=$(echo "${DOCKER_COMPOSE_OVERRIDE}" | python -c "import sys; print(sys.stdin.read().split('.')[2])")
                    echo "      - ${LATEST_IMAGE}-${OVERRIDE_NAME}" >> /tmp/docker-compose-cache-override.yaml
                    docker-compose -f docker-compose.yaml -f /tmp/docker-compose-cache-override.yaml \
                                   -f "${DOCKER_COMPOSE_OVERRIDE}" build $APP
                    [ "$?" != "0" ] && exit 1
                    docker tag ckan-multi-$APP "${LATEST_IMAGE}-${OVERRIDE_NAME}" &&\
                    docker tag ckan-multi-$APP "${TAG_IMAGE}-${OVERRIDE_NAME}"
                    [ "$?" != "0" ] && exit 1
                done
            fi
        fi
    done
    exit 0

elif [ "${1}" == "deploy" ]; then
    for APP in $APPS; do
        LATEST_IMAGE="${DOCKER_IMAGE}:${APP}-latest"
        TAG_IMAGE="${DOCKER_IMAGE}:${APP}-${TRAVIS_COMMIT}"
        docker push "${LATEST_IMAGE}" &&\
        docker push "${TAG_IMAGE}"
        [ "$?" != "0" ] && exit 1
        if [ "${APP}" == "ckan" ]; then
            for DOCKER_COMPOSE_OVERRIDE in `ls .docker-compose.*.yaml`; do
                OVERRIDE_NAME=$(echo "${DOCKER_COMPOSE_OVERRIDE}" | python -c "import sys; print(sys.stdin.read().split('.')[2])")
                docker push "${LATEST_IMAGE}-${OVERRIDE_NAME}" &&\
                docker push "${TAG_IMAGE}-${OVERRIDE_NAME}"
                [ "$?" != "0" ] && exit 1
            done
        fi
    done
    echo "Published Docker images:"
    for APP in $APPS; do
        LATEST_IMAGE="${DOCKER_IMAGE}:${APP}-latest"
        TAG_IMAGE="${DOCKER_IMAGE}:${APP}-${TRAVIS_COMMIT}"
        echo "${LATEST_IMAGE}"
        echo "${TAG_IMAGE}"
        if [ "${APP}" == "ckan" ]; then
            for DOCKER_COMPOSE_OVERRIDE in `ls .docker-compose.*.yaml`; do
                OVERRIDE_NAME=$(echo "${DOCKER_COMPOSE_OVERRIDE}" | python -c "import sys; print(sys.stdin.read().split('.')[2])")
                echo "${LATEST_IMAGE}-${OVERRIDE_NAME}"
                echo "${TAG_IMAGE}-${OVERRIDE_NAME}"
            done
        fi
    done
    exit 0

fi

echo unexpected failure
exit 1
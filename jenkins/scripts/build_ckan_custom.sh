#!/usr/bin/env bash

sudo docker-compose -f docker-compose.yaml -f .docker-compose-cache-from.yaml build ckan &&\
sudo docker tag viderum/ckan-cloud-docker:ckan-latest ${DOCKER_IMAGE} &&\
if ! [ -z "${DOCKER_PUSH_IMAGE}" ]; then
    sudo docker tag ${DOCKER_IMAGE} ${DOCKER_PUSH_IMAGE} &&\
    sudo docker push ${DOCKER_PUSH_IMAGE}
fi &&\
echo "

${DOCKER_PUSH_IMAGE:-$DOCKER_IMAGE}

"

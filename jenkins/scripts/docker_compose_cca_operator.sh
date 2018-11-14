#!/usr/bin/env bash

if [ "${QUIET}" == "1" ]; then
    sudo docker-compose build cca-operator >/dev/null 2>&1  &&\
    sudo docker-compose run --rm cca-operator 2>/dev/null "$@"
else
    sudo docker-compose build cca-operator &&\
    sudo docker-compose run --rm cca-operator "$@"
fi


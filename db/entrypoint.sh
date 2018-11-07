#!/usr/bin/env bash

if ! [ -z "${DATASTORE_PUBLIC_RO_PASSWORD}" ]; then
    echo Starting datastore-public-ro supervisord...
    ! supervisord -c /db-scripts/datastore-public-ro-supervisord.conf \
        && echo failed to start datastore-public-ro-supervisord && exit 1
    ! supervisorctl -c /db-scripts/datastore-public-ro-supervisord.conf status \
        && echo failed to get datastore-public-ro supervisor status && exit 1
    echo

fi

exec /usr/local/bin/docker-entrypoint.sh "$@"

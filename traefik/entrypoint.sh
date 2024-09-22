#!/bin/sh
set -e

# Update the Traefik configuration file with secrets if not development mode
if [ -f /traefik.dev.toml ]; then
    echo "Using development configuration"
    cp /traefik.dev.toml /traefik.toml
else
    if [ ! -f /traefik.toml.template ]; then
        echo "Traefik template file does not exist, exiting"
        exit 1
    fi
    if [ ! -f /traefik-secrets.sh ]; then
        echo "Traefik secrets file does not exist. Please run 'make secret' to generate it before starting the container"
        exit 1
    fi
    if [ ! -f /templater.sh ]; then
        echo "Templater script does not exist, exiting"
        exit 1
    fi

    echo "Traefik configuration file does not exist, templating"

    chmod +x /templater.sh
    ./templater.sh /traefik.toml.template -f /traefik-secrets.sh > traefik.toml
fi

# Fix acme.json file permissions: set to 600
chmod 600 /acme.json

# first arg is `-f` or `--some-option`
if [ "${1#-}" != "$1" ]; then
    set -- traefik "$@"
fi

# if our command is a valid Traefik subcommand, let's invoke it through Traefik instead
# (this allows for "docker run traefik version", etc)
if traefik "$1" --help | grep -s -q "help"; then
    set -- traefik "$@"
fi

exec "$@"

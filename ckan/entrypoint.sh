#!/usr/bin/env bash

source $CKAN_K8S_SECRETS &&\
rm -f $CKAN_CONFIG/*.ini &&\
cp -f $CKAN_K8S_TEMPLATES/${CKAN_WHO_TEMPLATE_PREFIX}who.ini $CKAN_CONFIG/who.ini &&\
bash /templater.sh $CKAN_K8S_TEMPLATES/${CKAN_CONFIG_TEMPLATE_PREFIX}production.ini.template > $CKAN_CONFIG/production.ini &&\
echo 'production.ini:' && cat $CKAN_CONFIG/production.ini &&\
bash /templater.sh $CKAN_K8S_TEMPLATES/${CKAN_INIT_TEMPLATE_PREFIX}ckan_init.sh.template > $CKAN_CONFIG/ckan_init.sh &&\
echo 'ckan_init.sh:' && cat $CKAN_CONFIG/ckan_init.sh &&\
bash $CKAN_CONFIG/ckan_init.sh
[ "$?" != "0" ] && echo ERROR: CKAN Initialization failed && exit 1

echo '--START_CKAN_CLOUD_LOG--{"event":"ckan-entrypoint-initialized"}--END_CKAN_CLOUD_LOG--' >/dev/stderr

if [ "$DEBUG_MODE" == "TRUE" ]; then
    sleep 300
fi

if [ "$*" == "" ]; then
    echo running ckan-paster db init &&\
    ckan --config="${CKAN_CONFIG}/production.ini" db init &&\
    echo db initialization complete
    [ "$?" != "0" ] && echo ERROR: DB Initialization failed && exit 1

    echo '--START_CKAN_CLOUD_LOG--{"event":"ckan-entrypoint-db-init-success"}--END_CKAN_CLOUD_LOG--' >/dev/stderr

    echo running ckan_extra_init &&\
    . $CKAN_CONFIG/ckan_extra_init.sh &&\
    echo ckan_extra_init complete
    [ "$?" != "0" ] && echo ERROR: CKAN extra initialization failed && exit 1

    echo '--START_CKAN_CLOUD_LOG--{"event":"ckan-entrypoint-extra-init-success"}--END_CKAN_CLOUD_LOG--' >/dev/stderr
    
    ckan --config="${CKAN_CONFIG}/production.ini" run --host 0.0.0.0
    #exec ${CKAN_VENV}/bin/gunicorn --paste ${CKAN_CONFIG}/production.ini --workers ${GUNICORN_WORKERS} --timeout ${GUNICORN_TIMEOUT}
else
    sleep 180
    exec "$@"
fi

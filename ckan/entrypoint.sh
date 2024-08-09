#!/usr/bin/env bash

source $CKAN_K8S_SECRETS &&\
rm -f $CKAN_CONFIG/*.ini &&\
cp -f $CKAN_K8S_TEMPLATES/${CKAN_WHO_TEMPLATE_PREFIX}who.ini $CKAN_CONFIG/who.ini &&\
bash /templater.sh $CKAN_K8S_TEMPLATES/${CKAN_CONFIG_TEMPLATE_PREFIX}ckan.ini.template > $CKAN_CONFIG/ckan.ini &&\
echo 'ckan.ini:' && cat $CKAN_CONFIG/ckan.ini &&\
bash /templater.sh $CKAN_K8S_TEMPLATES/${CKAN_INIT_TEMPLATE_PREFIX}ckan_init.sh.template > $CKAN_CONFIG/ckan_init.sh &&\
echo 'ckan_init.sh:' && cat $CKAN_CONFIG/ckan_init.sh &&\
bash $CKAN_CONFIG/ckan_init.sh
CKAN_CONFIG_PATH="$CKAN_CONFIG/ckan.ini"

[ "$?" != "0" ] && echo ERROR: CKAN Initialization failed: $? && exit 1

echo '--START_CKAN_CLOUD_LOG--{"event":"ckan-entrypoint-initialized"}--END_CKAN_CLOUD_LOG--' >/dev/stderr

if [ "$DEBUG_MODE" == "TRUE" ]; then
    sleep 300
fi

if [ "$*" == "" ]; then
    echo running ckan db init &&\
    ckan -c ${CKAN_CONFIG_PATH} db init &&\
    echo db initialization complete
    [ "$?" != "0" ] && echo ERROR: DB Initialization failed && exit 1

    echo '--START_CKAN_CLOUD_LOG--{"event":"ckan-entrypoint-db-init-success"}--END_CKAN_CLOUD_LOG--' >/dev/stderr

    echo running ckan_extra_init &&\
    . $CKAN_CONFIG/ckan_extra_init.sh &&\
    echo ckan_extra_init complete
    [ "$?" != "0" ] && echo ERROR: CKAN extra initialization failed && exit 1

    echo '--START_CKAN_CLOUD_LOG--{"event":"ckan-entrypoint-extra-init-success"}--END_CKAN_CLOUD_LOG--' >/dev/stderr

    ## Generate a random password
    #RANDOM_PASSWORD=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c 12)

    #echo "Creating system admin user 'ckan_admin'"
    #yes y | ckan -c $CKAN_CONFIG_PATH sysadmin add ckan_admin email=ckan_admin@localhost password=$RANDOM_PASSWORD
    #echo "Setting up ckan.datapusher.api_token in the CKAN config file $CKAN_CONFIG_PATH"
    #CKAN_API_KEY=$(ckan -c $CKAN_CONFIG_PATH user token add ckan_admin datapusher | tail -n 1 | tr -d '\t')
    #echo "CKAN_API_KEY: $CKAN_API_KEY"
    #ckan config-tool $CKAN_CONFIG_PATH "ckan.datapusher.api_token=$CKAN_API_KEY"
    #cat $CKAN_CONFIG_PATH | grep ckan.datapusher.api_token

    #ckan config-tool $CKAN_CONFIG_PATH -e "ckan.plugins = image_view text_view recline_view datastore datapusher resource_proxy geojson_view querytool stats"

    source /usr/lib/ckan/venv/bin/activate

    export CKAN_INI=$CKAN_CONFIG_PATH
    export PYTHONPATH=/usr/lib/ckan/venv:$PYTHONPATH

    # Set the common uwsgi options
    UWSGI_OPTS="--plugins-dir /usr/lib/uwsgi/plugins \
                --plugins http \
                --socket /tmp/uwsgi.sock \
                --wsgi-file /usr/lib/ckan/venv/wsgi.py \
                --module wsgi:application \
                --callable application \
                --virtualenv /usr/lib/ckan/venv \
                --uid 900 --gid 900 \
                --http [::]:5000 \
                --master --enable-threads \
                --lazy-apps \
                -p 2 -L -b 32768 --vacuum \
                --harakiri 300"

    # Start supervisord
    supervisord --configuration /etc/supervisord.conf &
    # Start uwsgi
    uwsgi $UWSGI_OPTS

else
    sleep 180
    exec "$@"
fi

#!/usr/bin/env bash

[ "${1}" == "--help" ] && echo ./server.sh && exit 0

if ! [ -e /etc/ckan-cloud/cca-operator/sshd_authorized_keys ]; then
    mkdir -p /etc/ckan-cloud/cca-operator &&\
    touch /etc/ckan-cloud/cca-operator/sshd_authorized_keys
    [ "$?" != "0" ] && exit 1
fi

mkdir -p /root/.ssh &&\
cp /etc/ckan-cloud/cca-operator/sshd_authorized_keys /root/.ssh/authorized_keys &&\
chmod 600 /root/.ssh/authorized_keys &&\
echo '#!/usr/bin/env bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export KUBECONFIG='${KUBECONFIG}'
export CF_AUTH_EMAIL='${CF_AUTH_EMAIL}'
export CF_AUTH_KEY='${CF_AUTH_KEY}'
export CF_ZONE_NAME='${CF_ZONE_NAME}'
export CF_ZONE_UPDATE_DATA_TEMPLATE='${CF_ZONE_UPDATE_DATA_TEMPLATE}'
export CF_RECORD_NAME_SUFFIX='${CF_RECORD_NAME_SUFFIX}'
cd /cca-operator
exec "$@"' > /root/cca-operator.sh && chmod +x /root/cca-operator.sh

/usr/sbin/sshd -E /var/log/sshd.log &&\
exec tail -f /var/log/sshd.log

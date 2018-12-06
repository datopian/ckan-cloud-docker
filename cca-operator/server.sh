#!/usr/bin/env bash

[ "${1}" == "--help" ] && echo ./server.sh && exit 0

if ! [ -e /etc/ckan-cloud/cca-operator/sshd_authorized_keys ]; then
    mkdir -p /etc/ckan-cloud/cca-operator &&\
    touch /etc/ckan-cloud/cca-operator/sshd_authorized_keys
    [ "$?" != "0" ] && exit 1
fi

if ! [ -e /etc/ssh/ssh_host_rsa_key ]; then ! ssh-keygen -t rsa -f /etc/ssh/ssh_host_rsa_key -N "" && exit 1; fi
if ! [ -e /etc/ssh/ssh_host_dsa_key ]; then ! ssh-keygen -t dsa -f /etc/ssh/ssh_host_dsa_key -N "" && exit 1; fi
if ! [ -e /etc/ssh/ssh_host_ecdsa_key ]; then ! ssh-keygen -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key -N "" && exit 1; fi
if ! [ -e /etc/ssh/ssh_host_ed25519_key ]; then ! ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N "" && exit 1; fi

mkdir -p /root/.ssh &&\
cp /etc/ckan-cloud/cca-operator/sshd_authorized_keys /root/.ssh/authorized_keys &&\
chmod 600 /root/.ssh/authorized_keys &&\
echo '#!/usr/bin/env bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export KUBECONFIG='"${KUBECONFIG}"'
source /etc/ckan-cloud/.cca_operator-secrets.env
cd /cca-operator
exec "$@"' > /root/cca-operator.sh && chmod +x /root/cca-operator.sh

/usr/sbin/sshd -E /var/log/sshd.log &&\
exec tail -f /var/log/sshd.log

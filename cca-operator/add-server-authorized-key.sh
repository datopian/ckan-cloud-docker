#!/usr/bin/env bash

[ "${1}" == "--help" ] && echo cat ~/.ssh/id_rsa.pub '|' ./add-server-authorized-key.sh && exit 0

mkdir -p /root/.ssh &&\
mkdir -p /etc/ckan-cloud/cca-operator &&\
cat >> /etc/ckan-cloud/cca-operator/sshd_authorized_keys
[ "$?" != "0" ] && exit 1

echo Added authorized key
exit 0

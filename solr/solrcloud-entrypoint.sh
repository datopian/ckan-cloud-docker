#!/usr/bin/env bash

mkdir -p /opt/solr/server/solr

! [ -e /opt/solr/server/solr/zoo.cfg ] && cp ckan_cloud/zoo.cfg /opt/solr/server/solr/
! [ -e /opt/solr/server/solr/solr.xml ] && cp ckan_cloud/solr.xml /opt/solr/server/solr/

chown -R $SOLR_USER:$SOLR_USER /opt/solr

echo #!/usr/bin/env bash > /_solrcloud_entrypoint.sh
echo export PATH='"'"${PATH}"'"' >> /_solrcloud_entrypoint.sh
echo docker-entrypoint.sh "$@" >> /_solrcloud_entrypoint.sh
chmod +x /_solrcloud_entrypoint.sh
chown $SOLR_USER:$SOLR_USER /_solrcloud_entrypoint.sh
exec sudo -HEu $SOLR_USER /_solrcloud_entrypoint.sh

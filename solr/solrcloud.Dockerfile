FROM solr:6.6.2

USER root

RUN apt-get update && apt-get install -y sudo

# add default ckan configset
ADD solrconfig.xml \
https://raw.githubusercontent.com/apache/lucene-solr/releases/lucene-solr/6.6.2/solr/server/solr/configsets/basic_configs/conf/currency.xml \
https://raw.githubusercontent.com/apache/lucene-solr/releases/lucene-solr/6.6.2/solr/server/solr/configsets/basic_configs/conf/synonyms.txt \
https://raw.githubusercontent.com/apache/lucene-solr/releases/lucene-solr/6.6.2/solr/server/solr/configsets/basic_configs/conf/stopwords.txt \
https://raw.githubusercontent.com/apache/lucene-solr/releases/lucene-solr/6.6.2/solr/server/solr/configsets/basic_configs/conf/protwords.txt \
https://raw.githubusercontent.com/apache/lucene-solr/releases/lucene-solr/6.6.2/solr/server/solr/configsets/data_driven_schema_configs/conf/elevate.xml \
ckan_default/conf/

ARG SCHEMA_XML=schemas/schema28.xml
COPY $SCHEMA_XML ckan_default/conf/schema.xml

COPY zoo.cfg ckan_cloud/zoo.cfg
COPY solr.xml ckan_cloud/solr.xml
COPY solrcloud-entrypoint.sh /opt/docker-solr/scripts/

ENTRYPOINT ["/opt/docker-solr/scripts/solrcloud-entrypoint.sh"]

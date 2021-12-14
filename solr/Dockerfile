FROM solr:6.6.6

# Enviroment
ENV SOLR_CORE ckan

# Create Directories
RUN mkdir -p /opt/solr/server/solr/$SOLR_CORE/conf
RUN mkdir -p /opt/solr/server/solr/$SOLR_CORE/data

# Adding Files
COPY solrconfig.xml /opt/solr/server/solr/$SOLR_CORE/conf/
COPY basic-config/ /opt/solr/server/solr/$SOLR_CORE/conf/
RUN ls /opt/solr/server/solr/$SOLR_CORE/conf/

ARG SCHEMA_XML=schemas/schema28.xml
COPY $SCHEMA_XML /opt/solr/server/solr/$SOLR_CORE/conf/schema.xml

# Create Core.properties
RUN echo name=$SOLR_CORE > /opt/solr/server/solr/$SOLR_CORE/core.properties

# Giving ownership to Solr

USER root
RUN chown -R $SOLR_USER:$SOLR_USER /opt/solr/server/solr/$SOLR_CORE

# User
USER $SOLR_USER:$SOLR_USER

FROM postgis/postgis:12-3.1-alpine

ARG APK_REPOSITORY

RUN apk --update add supervisor --update-cache --repository ${APK_REPOSITORY} --allow-untrusted

#RUN apk add --no-cache postgis
#
#RUN mkdir -p /usr/local/share/postgresql/extension
#
#RUN cp /usr/share/postgresql15/extension/postgis.control /usr/local/share/postgresql/extension/
#
COPY init_ckan_db.sh /docker-entrypoint-initdb.d/
COPY *.sh /db-scripts/
COPY datastore-permissions.sql.template /db-scripts/
COPY datastore-public-ro-supervisord.conf /db-scripts/

ARG DB_INIT
RUN echo "${DB_INIT}" >> /docker-entrypoint-initdb.d/init_ckan_db.sh

ENTRYPOINT ["/db-scripts/entrypoint.sh"]
CMD ["postgres"]

FROM postgres:9.6.3-alpine

RUN apk --update add supervisor

COPY init_db.sh /docker-entrypoint-initdb.d/
COPY *.sh /db-scripts/
COPY datastore-permissions.sql.template /db-scripts/
COPY datastore-public-ro-supervisord.conf /db-scripts/

ENTRYPOINT ["/db-scripts/entrypoint.sh"]
CMD ["postgres"]

FROM viderum/ckan-ng-harvest:latest

RUN echo "************** Installing dependencies ... **************" && \
    apt-get update && \
        apt-get install -y wget gnupg

ENV APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=DontWarn
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ jessie-pgdg main" | tee /etc/apt/sources.list.d/pgdg.list && \
        wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
        echo "************** Installing dependencies ... **************" && \
        apt-get update && \
        mkdir -p /usr/share/man/man1 && \
        mkdir -p /usr/share/man/man3 && \
        mkdir -p /usr/share/man/man7 && \
        apt-get install -y --no-install-recommends postgresql-client


RUN export CKAN_API_KEY=$(psql postgresql://ckan:123456@db/ckan -c -t "select apikey from public.user where name='admin';");echo "[$CKAN_API_KEY]";

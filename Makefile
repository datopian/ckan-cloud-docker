.PHONY: start stop build pull shell down remove logs user sysadmin secret cron

start:
	docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.$O-theme.yaml up -d --build nginx && make cron

stop:
	docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.$O-theme.yaml stop

build:
	docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.$O-theme.yaml build

pull:
	docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.$O-theme.yaml pull

shell:
	docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.$O-theme.yaml exec $S $C

down:
	docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.$O-theme.yaml down

remove:
	docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.$O-theme.yaml down -v

logs:
	docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.$O-theme.yaml logs -f $S
user:
	docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.$O-theme.yaml \
	 exec ckan /usr/local/bin/ckan-paster --plugin=ckan user add $U password=$P email=$E -c /etc/ckan/production.ini
sysadmin:
	docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.$O-theme.yaml \
	 exec ckan /usr/local/bin/ckan-paster --plugin=ckan sysadmin add $U -c /etc/ckan/production.ini
secret:
	python create_secrets.py
cron:
	docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.$O-theme.yaml exec --user=root ckan service cron start

.PHONY: start stop build pull shell down remove remove-images logs logs-less exec user sysadmin secret cron clean-rebuild

COMPOSE_FILES = -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.$O-theme.yaml

start:
	docker-compose $(COMPOSE_FILES) up -d --build nginx && make cron

stop:
	docker-compose $(COMPOSE_FILES) stop

build:
	docker-compose $(COMPOSE_FILES) build

pull:
	docker-compose $(COMPOSE_FILES) pull

shell:
	docker-compose $(COMPOSE_FILES) exec $S $C

down:
	docker-compose $(COMPOSE_FILES) down

remove:
	docker-compose $(COMPOSE_FILES) down -v

remove-images:
	docker images -a | grep "ckan-cloud-docker" | awk '{print $$3}' | xargs docker rmi -f

logs:
	docker-compose $(COMPOSE_FILES) logs -f $S

logs-less:
	docker-compose $(COMPOSE_FILES) logs $S | less

exec:
	docker-compose $(COMPOSE_FILES) exec $S $C

user:
	docker-compose $(COMPOSE_FILES) exec ckan /usr/local/bin/ckan-paster --plugin=ckan user add $U password=$P email=$E -c /etc/ckan/production.ini

sysadmin:
	docker-compose $(COMPOSE_FILES) exec ckan /usr/local/bin/ckan-paster --plugin=ckan sysadmin add $U -c /etc/ckan/production.ini

secret:
	python create_secrets.py

cron:
	docker-compose $(COMPOSE_FILES) exec --user=root ckan service cron start

clean-rebuild:
	docker-compose $(COMPOSE_FILES) down -v
	docker images -a | grep "ckan-cloud-docker" | awk '{print $$3}' | xargs docker rmi -f
	docker-compose $(COMPOSE_FILES) build --no-cache
	docker-compose $(COMPOSE_FILES) up -d --build nginx && make cron

.PHONY: start stop build pull shell down remove remove-images logs logs-less exec user sysadmin secret cron clean-rebuild

COMPOSE_FILES = -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.$O-theme.yaml

DATAPUSHER_TYPE ?= datapusher-plus
CKAN_DB_NAME ?= ckan
CKAN_DB_USERNAME ?= ckan
DB_USERNAME ?= postgres
DATASTORE_DB_NAME ?= datastore
DATASTORE_DB_USERNAME ?= postgres

start:
	@export DATAPUSHER_DIRECTORY=$(DATAPUSHER_TYPE) && \
	docker-compose $(COMPOSE_FILES) up -d --build nginx && make cron

stop:
	docker-compose $(COMPOSE_FILES) stop

build:
	@export DATAPUSHER_DIRECTORY=$(DATAPUSHER_TYPE) && \
	docker-compose $(COMPOSE_FILES) build

pull:
	docker-compose $(COMPOSE_FILES) pull

shell:
	docker-compose $(COMPOSE_FILES) exec -it $S sh -c 'if command -v bash > /dev/null 2>&1; then exec bash; else exec sh; fi'

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
	docker-compose $(COMPOSE_FILES) exec ckan ckan -c /etc/ckan/ckan.ini user add $U password=$P email=$E

sysadmin:
	docker-compose $(COMPOSE_FILES) exec ckan ckan -c /etc/ckan/ckan.ini sysadmin add $U

secret:
	python create_secrets.py

cron:
	docker-compose $(COMPOSE_FILES) exec --user=root ckan service cron start

clean-rebuild:
	docker-compose $(COMPOSE_FILES) down -v
	docker images -a | grep "ckan-cloud-docker" | awk '{print $$3}' | xargs -r docker rmi -f
	@export DATAPUSHER_DIRECTORY=$(DATAPUSHER_TYPE) && \
	docker-compose $(COMPOSE_FILES) build --no-cache
	@export DATAPUSHER_DIRECTORY=$(DATAPUSHER_TYPE) && \
	docker-compose $(COMPOSE_FILES) up -d nginx && make cron

backup-db:
	docker-compose $(COMPOSE_FILES) exec -T db pg_dump -U postgres --format=custom -d ckan > ckan_test.dump
	docker-compose ${COMPOSE_FILES} exec -T ckan sh -c "cd /var/lib/ckan && tar -czf /tmp/ckan_data_test.tar.gz data"
	docker cp $$(docker-compose ${COMPOSE_FILES} ps -q ckan):/tmp/ckan_data_test.tar.gz ckan_data_test.tar.gz
	docker-compose $(COMPOSE_FILES) exec -T datastore-db pg_dump -U postgres --format=custom -d datastore > datastore_test.dump

upgrade-db:
	./db/migration/upgrade_databases.sh "$(COMPOSE_FILES)" "$(CKAN_DB_NAME)" "$(CKAN_DB_USERNAME)" "$(DB_USERNAME)" "$(DATASTORE_DB_NAME)" "$(DATASTORE_DB_USERNAME)"

config-upgrade:
	./configs_diff.sh

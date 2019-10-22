# Running CKAN NG harvester

## Purpose of this document

This document details the procedure to run the CKAN Next Generation harvesters.  
This includes:
 - a CKAN instance to harvest to.
 - Airflow service to schedule and run harvest jobs periodically.

## Related links

- [CKAN NG harvester](https://gitlab.com/datopian/ckan-ng-harvest)
- [Core CKAN harvester](https://pypi.org/project/ckan-harvester/)
- [Airflow](https://airflow.apache.org/)
- [ViderumGlobal/ckan-cloud-docker GitHub repository](https://github.com/ViderumGlobal/ckan-cloud-docker)

## Bring up the CKAN Harvester NG instance

### Build the Harvester NG image

**This will be removed when we register this image.**  

Clone the CKAN NG harveter repo: https://gitlab.com/datopian/ckan-ng-harvest.  
Follow the instruction at the [docker.md](https://gitlab.com/datopian/ckan-ng-harvest/blob/develop/docker.md) file in order to build the image with the tag _viderum/ckan-harvest-ng_.  

```
docker build -t viderum/ckan-harvest-ng:latest .
```

Now we have lcoally registered the _viderum/ckan-harvest-ng_ docker image.  

### Running the full docker envirnoment

Go back to the _ckan-clod-docker_ folder (this repo).  

Run and follow all steps:
```
./create_secrets.py
```

Start the Docker compose environment with all its components.

```
docker-compose \
      -f docker-compose.yaml \
      -f .docker-compose-db.yaml \
      -f .docker-compose.datagov-theme.yaml \
      -f .docker-compose.harvester_ng.yaml \
      up -d --build nginx harvester
```

Add a hosts entry mapping domain `nginx` to `127.0.0.1`:

```
127.0.0.1 nginx
```

Create a CKAN admin user

```
docker-compose \
      exec ckan ckan-paster \
      --plugin=ckan \
      sysadmin add \
      -c /etc/ckan/production.ini \
      admin password=12345678 \
      email=admin@localhost
```

Now you are able to togin to CKAN at http://nginx:8080 with username `admin` and password `12345678`


### Other tools

Clean all the data at the images

```
docker-compose \
      -f docker-compose.yaml \
      -f .docker-compose-db.yaml \
      -f .docker-compose.datagov-theme.yaml \
      -f .docker-compose.harvester_ng.yaml \
      down -v
```

Check logs

```
$ docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.datagov-theme.yaml \
      logs -f
```
# Running unit tests tests on ViderumGlobal/ckan-cloud-docker

## Purpose of this document

This document details the procedure to be followed when running unit tests on ViderumGlobal/ckan-cloud-docker using nosetests

## Related links

* [ViderumGlobal/ckan-cloud-docker GitHub repository](https://github.com/ViderumGlobal/ckan-cloud-docker)
* [Contributing guide: Testing CKAN](https://docs.ckan.org/en/2.8/contributing/test.html) - about back-end tests and Front-end tests
* [Extending guide: Testing extensions](https://docs.ckan.org/en/2.8/extensions/testing-extensions.html)
* [Contributing guide: Testing coding standards](https://docs.ckan.org/en/2.8/contributing/testing.html)

## Bring up the CKAN stack instance

The following instructions deviate a bit from the instructions for bringing up a CKAN instance on your PC. Refer also to the installation instructions in the [ViderumGlobal/ckan-cloud-docker repository](https://github.com/ViderumGlobal/ckan-cloud-docker).

First, cd to the directory containing your `docker-compose.yaml`, `.docker-compose-db.yaml` and `.docker-compose.datagov-theme.yaml` files.

```
$ cd ckan-cloud-docker
```

(optional) Eensure a fresh start with up-to-date images:


```
$ docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.datagov-theme.yaml \
      down -v
```
Then remove images and volumes (only if you are paranoid).

Start the CKAN instance

```
$ docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.datagov-theme.yaml \
      up -d nginx

```

Wait several seconds until the instance stabilizes. You may monitor its initialization process using:
```
$ docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.datagov-theme.yaml \
      logs -f
```

The wait ends when
```
$ curl http://nginx:8080/api/3
```
responds successfully.

An unsuccessful response would be HTTP 502 (Bad Gateway). A successful response would be `{"version": 3}` not having newline at end.

Once you see a successful response, create a CKAN admin user:
```
$ docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.datagov-theme.yaml \
	  exec ckan ckan-paster --plugin=ckan \
      sysadmin add -c /etc/ckan/production.ini admin password=12345678 email=admin@localhost
```

You should see the following prompt:
```
User "admin" not found
Create new user: admin? [y/n]
```
Enter y and now you should see:
```
Creating user: 'admin'
{...
.
.
.
...}
Added admin as sysadmin
```


Now, if you want to, you can login to [http://nginx:8080](http://nginx:8080) with username `admin` and password `12345678`.

The following instructions are based upon [Testing CKAN - Back-end tests](https://docs.ckan.org/en/2.8/contributing/test.html#back-end-tests).

The first step is to start a shell inside the `ckan` service (implemented by the `ckan-cloud-docker_ckan_1` container).
```
$ docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.datagov-theme.yaml \
      exec ckan /bin/bash
```

The following commands are executed inside the container.
First, install development requirements.

```
$ . venv/bin/activate
$ ckan-pip install  -r venv/src/ckan/dev-requirements.txt
```
Verify that `nose` is installed by trying to import it:
```
$ python
Python 2.7.9 (default, Sep 25 2018, 20:42:16) 
[GCC 4.9.2] on linux2
Type "help", "copyright", "credits" or "license" for more information.
>>> import nose
>>> exit(0)
```

Exit the shell and the container.
```
$ exit
```

Now prepare the datastore DB for unit tests as follows.

Start `psql` inside the `datastore-db` service (the `ckan-cloud-docker_datastore-db_1` container).

```
$ docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.datagov-theme.yaml \
      exec --user postgres datastore-db psql
```

Enter the following commands.

```
postgres=# CREATE ROLE ckan_default WITH LOGIN PASSWORD 'pass';
postgres=# CREATE ROLE datastore_default WITH LOGIN PASSWORD 'pass';
postgres-# \q
```
The last command closes psql and you are back in your host computer's shell. Now create the test databases:
```
$ docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.datagov-theme.yaml \
      exec --user postgres datastore-db createdb -O ckan_default ckan_test -E utf-8 -T template0
$ docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.datagov-theme.yaml \
      exec --user postgres datastore-db createdb -O ckan_default datastore_test -E utf-8 -T template0
```

The `-T template0` option is needed to fix a data encoding incompatibility in recent versions of PostgreSQL.

Copy `test-core.ini` (currently available in this repository as `TESTING.test-core.ini`) into the `ckan` service:
```
docker cp TESTING.test-core.ini ckan-cloud-docker_ckan_1:/usr/lib/ckan/venv/src/ckan/test-core.ini
```
Now we have to run a script in the `ckan` service and pipe its output into the `datastore-db` instance.
```
$ docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.datagov-theme.yaml \
      exec ckan /bin/bash
```
Inside the `ckan` service, execute:
```
$ . venv/bin/activate
$ cd /usr/lib/ckan/venv/src/ckan
$ export PGPASSWORD=123456
$ paster datastore set-permissions -c test-core.ini | psql -h datastore-db -U postgres
```

Solr is already configured as 'multi-core'. To verify it, you may run the following command inside the `ckan` container:
```
$ grep solr_url /etc/ckan/production.ini
# Possible outputs:
# single-core: solr_url = http://solr:8983/solr
# multi-core:  solr_url = http://solr:8983/solr/ckan
```

Finally, run the unit tests inside the `ckan` container:
```
$ . venv/bin/activate
$ nosetests --ckan --with-pylons=/usr/lib/ckan/venv/src/ckan/test-core.ini ckan ckanext
```

## CURRENT STATUS

As of May 1, 2019:

Ran 2298 tests in 2508.135 seconds.
* Skipped: 3 tests.
* Errors: 67 tests.
* Failures: 14 tests.

Some of the reasons for failure of tests are:
* Several test errors were due to 'http://nginx:8080' != 'http://test.ckan.net' (ckan.site_url).

# Deployment

This is a step by step guide covering all the necessary steps to deploy CKAN using custom template on a new machine.

The guide will try to cover all Linux-based operating systems, but some commands might be specific to Ubuntu and its derivatives. However, links containing further information were added in order to simplify the installation process on other operating systems as well.

## Installation

### Dependencies

* A GNU/Linux operating system with good internet connectivity.  
* Unrestricted access to external domains, such as **[GitHub](https://github.com/)**, **[DockerHub](https://hub.docker.com/)**, etc.
* git, docker-engine (docker) and docker-compose

First we need to install **[git](https://help.github.com/en/articles/set-up-git)** and **[docker-compose](https://docs.docker.com/compose/install/)** \(*docker-compose* should already have *docker* as dependency. If this is not the case follow the **[official documentation on installing docker](https://docs.docker.com/v17.12/install/)**\):

```
sudo apt-get update
sudo apt-get install git docker-compose build-essential
```

Then start and enable the docker service and verify operation

```
sudo systemctl start docker
sudo systemctl enable docker
sudo docker info
```

__Note:__ In case you need to use your local county mirrors as pip registry please set pip index URL:

```
export PIP_INDEX_URL=<<https://local-mirror-url.xy>>
```


#### Extra dependencies

- You will also need a SMTP server and its credentials for CKAN to work properly. This will not obstacle deployment, CKAN will be up and running, but won't be able to send emails (e.g. on password reset). You will be asked to provide SMTP server credentials while running `make secret` script, see below.

### Source files and configuration

Now we have the runtime, next we need to download the cluster configuration files and build the services.

Navigate to where you want the source files to live on your server (e.g. `/opt`) and clone the repository:

```
cd /opt
git clone https://github.com/ViderumGlobal/ckan-cloud-docker.git
cd ckan-cloud-docker
```

#### Environment variables
To create or update files with secrets and env vars run and follow all steps:
```
make secret
```

#### Traefik proxy service

Traefik is the entry point from the outside world. It binds to the default HTTP (80) and HTTPS (443) ports and handles requests by forwarding them to the appropriate services within the stack. In our case, it will point to Nginx serving the CKAN web app.

Traefik will set up SSL for the website. There are two ways of doing this:

1. By having a provided certificate we need to install
2. By obtaining and installing a Let's Encrypt certificate


##### Install a provided certificate

To install an existing SSL certificate we need to use the `traefik/traefik_custom_ssl.toml` file. Make sure this file is the one mounted in the Traefik container, and not the default (which will attempt to obtain a Let's Encrypt certificate, see next step).

The certificate chain and private key need to be copied in the `traefik/certs` directory using these exact names:

* `domain.cert` for the certificate [chain] of the domain
* `domain.key` for the private key

Modifying these names is possible by also altering the `traefik.toml` configuration file. This might be needed for installing multiple certificates, for example (subdomains, alternate TLDs etc.).

##### Set up Let's Encrypt

Traefik needs strict permissions in order to run Let's Encrypt \(**[more info](https://www.digitalocean.com/community/tutorials/how-to-use-traefik-as-a-reverse-proxy-for-docker-containers-on-ubuntu-18-04)**\):
```
chmod 600 traefik/acme.json
```

Finally, edit traefik/traefik.toml file

```
vim traefik/traefik.toml
```

Traefik will attempt to obtain a Let's Encrypt SSL certificate. In order for this to happen, the following configuration items need to be filled in:

* `email = "admin@example.com"`

> IMPORTANT: Use FQDN for both ‘main’ and ‘rule’ entries.


  This is the [contact email](https://letsencrypt.org/docs/expiration-emails/) for Let's Encrypt
* `main = "example.com"`
  This is the domain for which Let's Encrypt will generate a certificate for

---

In addition to SSL specific configuration, there is one more line you need to adjust:

* `rule = "Host:example.com"`
  This is the domain name that Traefik should respond to. Requests to any other domain not configured as a `Host` rule will result in Traefik not being able to handle the request.


> Note: All the necessary configuration items are marked with `TODO` flags in the `traefik.toml` configuration file.

---

This should be enough for the basic installation. In case you need to tweak versions or other initialization parameters for CKAN, you need these two files:

* `docker-compose/ckan-conf-templates/{instance-id}-theme-production.ini`
  This is the file used to generate the CKAN main configuration file.

* `.docker-compose.{instance-id}-theme.yaml`
  This is the file that defines the services used by this instance.


## Running

**To run the instance:**

```
sudo make start O=<<instance-id>>
```

**To stop it, run:**
```
sudo make stop O=<<instance-id>>
```

**To destroy the instance, run:**
```
sudo make down O=<<instance-id>>
```

**To destroy the instance, together with volumes, databases etc., run:**
```
sudo make remove_volumes O=<<instance-id>>
```

*If you want to tweak the source files, typically you need to destroy the instance and run it again once you're done editing. The choice of removing the volumes in the process is up to you.*

## Migrate Data

### Migrate Database

You will need public URLs to database dumps.

```
DB_DUMP_URL=<<DB_DUMP_URL.gz>>
DATASTORE_DB_DUMP_URL=<<DATASTORE_DB_DUMP_URL.gz>>

sudo make shell O=<<instance-id>> S=ckan C='bash migrate_databases.sh $(DB_DUMP_URL) $(DATASTORE_DB_DUMP_URL)'
```

### Migrate files

__For ckan-cloud devops only__ - Migrate data from ckan-cloud cluster to object store server (Eg: AWS S3):

```
# Grab the minio-mc pod name
kubectl get pods -n ckan-cloud | grep minio-mc
# SSH into the pod
kubectl exec -it minio-mc-xya-abc -n ckan-cloud sh
# Add minio server to hosts
mc config host add exporter https://host.ckan.io <<access-key>> <<secret-key>>
# Add client minio server to hosts
mc config host add receiver https://host.client.io <<reciever-access-key>> <<reciever-secret-key>>
# Depending on instance, some paths can be set to public download:
mc policy download prod/ckan/<<instance-id>>/*
# Make sure client server has bucket init with proper permissions. (IAM user owning credentials should have full access over bucket)
# Migrate data
mc cp --recursive exporter/ckan/<<instance-id>> receiver/<<bucket-name>>
```

Download the data to file system and mount on ckan persistent volumes:

```
HOST=<<FileStorage Server>>
ACCESS_KEY=<<Access Key>>
SECRET_KEY=<<Secret Key>>
BUCKET=<<Bucket Name>>
STORAGE_PATH=<<Storage Path>>

bash migrate_filestorage.sh $HOST $ACCESS_KEY $SECRET_KEY $BUCKET $STORAGE_PATH
```

### Repopulate search index

After migration rebuild the SOLR search index.
```
sudo make shell O=<<instance-id>> S=ckan C='/usr/local/bin/ckan-paster --plugin=ckan search-index rebuild  -c /etc/ckan/production.ini'
```

## Debugging

To check all the logs at any time:  
```
sudo make logs O=<<instance-id>>
```

To check the logs for a specific service:  
```
sudo make logs O=<<instance-id>> S=<<Service Name>>
```
*(exit the logs by pressing Ctrl+C at any time)*

To get inside a running ckan container


```
sudo make shell O=<<instance-id>> S=<<Service Name>> C=<<command>>
```

Note: for some services (Eg: Nginx) you mite need to use C=`sh` instead of c=`bash`

## Creating the sysadmin user

In order to create organizations and give other user proper permissions, you will need sysamin user(s) who has all the privileges. You can add as many sysadmin as you want. To create sysamin user:

```
# Create user using paster CLI tool
sudo make user O={instance-id} U={username} P={password} E={email}

# Example
sudo make user O=panama U=ckan_admin P=123456 E=info@datopian.com
```

You can also give sysadmin role to the existing user.

```
sudo make sysadmin O=panama U=ckan_admin
```

## Sysadmin Control Panel

Here you can edit portal related configuration, like website title, site logo or add custom styling. Login as sysadmin and navigate to `ckan-admin/config` page and make changes you need. Eg: https://demo.ckan.org/ckan-admin/config


## Installing and enabling a new extension

CKAN allows installing various extensions (plugins) to the existing core setup. In order to enable/disable them you will have to install them and include into the ckan config file.

To install extension you need to modify `POST_INSTALL` section of ckan service in `.docker-compose.{instance-id}-theme.yaml`. Eg to install s3filestore extension

```
POST_INSTALL: |
  install_standard_ckan_extension_github -r datopian/ckanext-s3filestore &&\
```

And add extension to the list of plugins in `docker-compose/ckan-conf-templates/{instance-id}-theme-production.ini.template`

```
# in docker-compose/ckan-conf-templates/{instance-id}-theme-production.ini.template
ckan.plugins = image_view
   ...
   stats
   s3filestore
```

Note: depending on extension you might also need to update extensions related configurations in the same file. If needed this type of information is ussually included in extension REAMDE.

```
# in docker-compose/ckan-conf-templates/{instance-id}-theme-production.ini.template
ckanext.s3filestore.aws_access_key_id = Your-Access-Key-ID
ckanext.s3filestore.aws_secret_access_key = Your-Secret-Access-Key
ckanext.s3filestore.aws_bucket_name = a-bucket-to-store-your-stuff
ckanext.s3filestore.host_name = host-to-S3-cloud storage
ckanext.s3filestore.region_name= region-name
ckanext.s3filestore.signature_version = signature (s3v4)
```

In order to disable extension you can simple remove it from the list of plugins. You will probably also want to remove it from `POST_INSTALL` part to avoid redundant installs, although this is not must.

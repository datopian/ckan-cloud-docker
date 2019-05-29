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
sudo apt update
sudo apt instal git docker-compose
```

Then start and enable the docker service and verify operation

```
sudo systemctl start docker
sudo systemctl enable docker
sudo docker info
```

### Source files and configuration

Now we have the runtime, next we need to download the cluster configuration files and build the services.

Navigate to where you want the source files to live on your server (e.g. `/opt`) and clone the repository:

```
cd /opt
git clone https://github.com/ViderumGlobal/ckan-cloud-docker.git
cd ckan-cloud-docker
```

#### Environment variables

To change the default env vars used throughout the [CKAN configuration file](./docker-compose/ckan-conf-templates), adjust the secrets in `docker-compose/ckan-secrets.sh`:

```
vim docker-compose/ckan-secrets.sh
```

#### Traefik proxy service

Traefik is the entry point from the outside world. It binds to the default HTTP (80) and HTTPS (443) ports and handles requests by forwarding them to the appropriate services within the stack. In our case, it will point to Nginx serving the CKAN web app.

Traefik needs strict permissions in order to run \(**[more info](https://www.digitalocean.com/community/tutorials/how-to-use-traefik-as-a-reverse-proxy-for-docker-containers-on-ubuntu-18-04)**\):
```
chmod 600 traefik/acme.json
```

Finally, edit traefik/traefik.toml file

```
vim traefik/traefik.toml
```

Traefik will attempt to obtain a Let's Encrypt SSL certificate. In order for this to happen, the following configuration items need to be filled in:

* `email = "admin@example.com"`
  This is the [contact email](https://letsencrypt.org/docs/expiration-emails/) for Let's Encrypt
* `main = "example.com"`
  This is the domain for which Let's Encrypt will generate a certificate for

In addition to Let's Encrypt specific configuration, there is one more line you need to adjust:

* `rule = "Host:example.com"`
  This is the domain name that Traefik should respond to. Requests to any other domain not configured as a `Host` rule will result in Traefik not being able to handle the request.


> Note: All the necessary configuration items are marked with `TODO` flags in the `traefik.toml` configuration file.


This should be enough for the basic installation. In case you need to tweak versions or other initialization parameters for CKAN, you need these two files:

* `docker-compose/ckan-conf-templates/vital-strategies-theme-production.ini`
  This is the file used to generate the CKAN main configuration file.
  
* `.docker-compose.vital-strategies-theme.yaml`
  This is the file that defines the services used by this instance.
  

## Running

**To run the `vital-strategies` instance:**

```
sudo docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.vital-strategies-theme.yaml up -d --build nginx
```

**To stop it, run:**
```
sudo docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.vital-strategies-theme.yaml stop
```

**To destroy the instance, run:**
```
sudo docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.vital-strategies-theme.yaml down
```

**To destroy the instance, together with volumes, databases etc., run:**
```
sudo docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.vital-strategies-theme.yaml down -v
```

*If you want to tweak the source files, typically you need to destroy the instance and run it again once you're done editing. The choice of removing the volumes in the process is up to you.*


## Debugging

To check all the logs at any time:  
```
sudo docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.vital-strategies-theme.yaml logs -f
```  

To check the logs for a specific service:  
```
sudo docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.vital-strategies-theme.yaml logs -f ckan
```  
*(exit the logs by pressing Ctrl+C at any time)*

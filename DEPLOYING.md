# Deployment

This is a step by step guide covering the necessary steps to deploy CKAN using custom template on a new machine.

The guide will try to cover all Linux-based operating systems, but some commands might be specific to Ubuntu and derivatives.


## Requirements

For this you need a GNU/Linux operating system with good internet connectivity. Access to other domains, such as GitHub, should not be compromised by external firewall settings.

First we need to install git and docker-compose:

```
sudo apt update
sudo apt instal git docker-compose
```

Then enable the docker service:

```
sudo systemctl enable docker
sudo systemctl start docker
```

Now we have the runtime, next we wil get the cluster configuration files and build the services.

## Source files and configuration

Navigate to where you want the source files to live on your server (e.g. `/opt`) and clone the repository:

```
cd /opt
git clone https://github.com/ViderumGlobal/ckan-cloud-docker.git
cd ckan-cloud-docker
```

Traefik needs strict permissions in order to run:

```
chmod 600 traefik/acme.json
```

Next, adjust the secrets in `docker-compose/ckan-secrets.sh`:

```
vim docker-compose/ckan-secrets.sh
```

This should be enough for the basic installation. In case you need to tweak versions or other initialization parameters for CKAN, you need these two files:

* `docker-compose/ckan-conf-templates/vital-strategies-theme-production.ini`
  This is the files used to generate the CKAN main configuration file.
  
* `.docker-compose.vital-strategies-theme.yaml`
  This is the file that defines the services used by this instance.
  

## Running

To run the `vital-strategies` instance, run:

```
sudo docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.vital-strategies-theme.yaml up -d --build nginx
```

To stop it, run:
```
sudo docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.vital-strategies-theme.yaml stop
```

To destroy the instance, run:
```
sudo docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.vital-strategies-theme.yaml down
```

To destroy the instance, together with volumes, databases etc., run:
```
sudo docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.vital-strategies-theme.yaml down -v
```


If you want to tweak the source files, typically you need to destroy the instance and run it again once you're done editing. The choice of removing the volumes in the process is up to you.

You can check all the logs at any time by running:

```
sudo docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.vital-strategies-theme.yaml logs -f
```
(exit the log by pressing Ctrl+C at any time)

Or just the logs for a specific service:

```
sudo docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.vital-strategies-theme.yaml logs -f ckan
```

# Deployment on Windows Server 2008 R2 SP1

[toc]

This is a step by step guide covering all the necessary steps to deploy CKAN using custom Vital Strategies Philippines template on Windows Server 2008 R2 SP1 machine.

The guide will try to cover all Windows based prerequisites and installation of needed software, but also will cover installation of Ubuntu 18.04 LTS in VirtualBox virtual machine. After that we will install CCD with Vital Strategies Philippines template and do the final setting and customization.

# Installation

## Hardware and software prerequisites

* Any computer with multicore CPU with basic virtualization capabilities
* 8GB RAM (more is desirable)
* Windows Server 2008 R2 SP1 64-bit installed
* At least 30 GB of hardrive free space for initial installation of VirtualBox, Ubuntu 18.04 inside VM and CCD with Vital Strategies template.


## Installation guide of CKAN instance for Philipines project on Ubuntu 18.04 LTS inside Virtual Box VM

### VirtualBox installation

#### Download VirtualBox installer for Windows

The installer can be found on its download page here https://www.virtualbox.org/wiki/Downloads

Go to the page above and download the binary version for Windows hosts

#### Run the installer and follow the instructions

![](https://i.imgur.com/47Qk8zV.png)

#### Custom setup dialog box

You will see custom setup dialog box. There is not much to choose from. You should accept the defaults and click next.

![](https://i.imgur.com/eJfBrNG.png)

VirtualBox Installation – Custom setup dialog box screenshot

#### Custom setup dialog box – Feature to install

In this dialog box you can choose which features to install. You can accept the defaults and click next.

![](https://i.imgur.com/R7aIe7b.png)

VirtualBox Installation – Custom Setup – Select feature to Install - screenshot

#### Network Interface setup

This dialog box warns you about setting up a Network Interface. what this means that VirtualBox will install network interfaces that will interact with the installed virtual machines and the host operating system which in our case is windows. This will temporarily disconnect you from the internet but that OK, nothing to worry.

![](https://i.imgur.com/NhpgPPG.png)

VirtualBox Installation – Network Interface warning - screenshot

#### Ready to Install

You will see ready to install dialog box.

![](https://i.imgur.com/WGvTus0.png)

VirtualBox Installation – Ready to Install

#### Installation begins

After clicking install, you will mostly probably see User access control confirmation dialog box from Windows OS. This is a security feature in Windows that wants to confirm if the application should be allowed to proceed with the installation process. Click Yes to continue and you will see that the installation process will begin. Wait for the installation to complete.

If you see Windows User Account Control Warning, click yes to accept and continue.

![](https://i.imgur.com/YWG81Qn.png)

VirtualBox Installation in Progress - screenshot

#### Installation Completes

After the installation completes, you will see installation completion dialog box. Check `Start Oracle VM VirtualBox after installation` and click on `Finish` button. 

![](https://i.imgur.com/IYbdSmO.png)

VirtualBox Installation complete

### Creating Vurtual Machine for Ubuntu 18.04 LTS installation

* Start VirtualBox
* Click on the `New` icon to create a new machine
* Give the name of your new VM
* Choose `Type` Linux
* Choose `Version` Ubuntu(64-bit)

![](https://i.imgur.com/JnZT6A0.png)

* Click on `Next`
* Increase memory size to the half of vailable memory (green is safe)

![](https://i.imgur.com/Tv3C4Zl.png)

* Click on `Next`
* Choose `Create a virtual hard disk now`

![](https://i.imgur.com/1JK4CCr.png)

* Click on `Create`
* Choose `VDI (VirtualBox Disk Image)`

![](https://i.imgur.com/dZZKq1Y.png)

* Click on `Next`
* Choose `Dynamically allocated`

![](https://i.imgur.com/pXwJeYP.png)

* Click on `Next`

![](https://i.imgur.com/lZKJaeu.png)

* In VirtualBox select your newly created VM and click on `Settings`
* In `System/Processor` tab, increase the number of CPUs to one half of available CPUs.
* Check `Enable PAE/NX`

![](https://i.imgur.com/rRDTAsf.png)

Your VM for Ubuntu installation is created and setup.

### Ubuntu 18.04 LTS inside VM installation

* Download Ubuntu 18.04 LTS installation `.iso` file from http://releases.ubuntu.com/18.04.4/ubuntu-18.04.4-desktop-amd64.iso
* In VirtualBox select your VM and click on `Start` icon

![](https://i.imgur.com/G0URd9t.png)

* Click on the folder icon and from your file explorer select the Ubuntu 18.04 iso file which you downloaded earlier. Once that is done and you can click on `Start` to begin the installation process.

![](https://i.imgur.com/YnfXjh8.png)

* Click on `Continue`
* In the next screen, you’ll be provided following beneath options including:
    * Type of Installation: choose `Normal installation`
    * Check `Download Updates While Installing Ubuntu` (select this option if your system has internet connectivity during installation)
    * Check `Install third party software for graphics and Wi-Fi hardware, MP3 and additional media formats`  (select this option if your system has internet connectivity)


![](https://i.imgur.com/TtKp68Y.png)

* Click on `Continue`

![](https://i.imgur.com/V4Iw9LD.png)

* Now choose `Erase disk and install Ubuntu` and click on `Continue`

![](https://i.imgur.com/5o60CRl.png)

* When you get warning message click on `Continue`
* A pop-up window will inform you what kind of changes it will make to your disk. Click on `Continue` to agree to the changes and erase any existing software on your drive.
* Next, it will ask you for your location (time zone). Select the appropriate one and press `Continue`.

![](https://i.imgur.com/g9pL3sX.png)

* Choose your `User name`, `Password` and `log in` option.
* Click on `Continue` to begin installation

![](https://i.imgur.com/86zeDT9.png)

* ... and wait to finish. When finished you will be asked to restart computer (in this case Ubuntu VM)

![](https://i.imgur.com/IaOvbnD.png)

* Click on `Restart Now`

### Additional settings for Ubuntu in VM

#### Git installation

Open `Terminal` app, than run following command:
```
sudo apt update
sudo apt install git
```

#### `docker-compose` installation

Open `Terminal` app, than run following command:
```
sudo apt update
sudo apt install docker-compose
```

### CKAN installation for Vital Strategies Philippines project

1. Clone repository from https://github.com/datopian/ckan-cloud-docker
```
git clone -b cd-windows-philippines https://github.com/datopian/ckan-cloud-docker
```

2. Change directory to `/ckan-cloud-docker` to enter the cloned folder.
```
cd ckan-cloud-docker
```

3. To create secrets run
```
python create_secrets.py
```

Hit `Enter` on every question except for `CKAN_SITE_URL` - here add `http://localhost:8080`

5. Build the image and start the application
```
docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.vital-strategies-philippines-theme.yaml up -d --build nginx
```

When finished you will get the prompt in your Terminal window.

6. Setup should be finished successfully. You can check logs with
```
docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.vital-strategies-philippines-theme.yaml logs -f
```

and when you see that CKAN is in the running state you can proceed.

7. Now we should create sysadmin user. Open another Terminal window and run following command twice. First run will create user `admin` with password `12345678`. The second run will promote `admin` to sysadmin user.
```
docker-compose exec ckan ckan-paster --plugin=ckan sysadmin add -c /etc/ckan/production.ini admin password=12345678 email=admin@localhost
```

8. At this moment we can access our CKAN server by visiting `localhost:8080` in browser inside Ubuntu VM.
Login to CKAN at http://localhost:8080 with username `admin` and password `12345678`.
You should be able to see

![](https://i.imgur.com/PSizKmS.png)

10. To close logs you should press `CTRL+C`

11. To stop your CKAN server you should run
```
docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.vital-strategies-philippines-theme.yaml down
```

## Expose CKAN to outside World

Now, it's time to make our CKAN instance to be visible from host Windows Server 2008.

Stop your CKAN server and turn off Ubuntu and VM.
Go to your Ubuntu VM settings and select `Network`

![](https://i.imgur.com/vL1qEYm.png)

Instead of `NAT`, choose `Bridge Adapter` and click on `OK`.

Start your Ubuntu VM again and open Terminal app.
Type
```
sudo apt install net-tools
```

After setup finishes type
```
ifconfig | grep inet
```

You should see something similar to this:

![](https://i.imgur.com/TT3ndrf.png)

The IP address of your Ubuntu in VM is from the domain of your local network - in this case `192.168.1.103`

Now you can access your CKAN instance from host Windows Server 2008 by visiting `192.168.1.103:8080`

#### Exposing CKAN instance outside Windows Server 2008

For that, we only need to create `inbound` rule in Windows Firewall for port `8080` to allow access through that port.

# Additional settings, customizations and debugging

## Traefik proxy service

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

**`instance-id`** in our case is `vital-strategies-philippines`

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


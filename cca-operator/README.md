# cca-operator

cca-operator manages, provisions and configures Ckan Cloud components inside a [Ckan Cloud cluster](https://github.com/ViderumGlobal/ckan-cloud-cluster).

## Running cca-operator

Build and run using docker-compose:

```
docker-compose build cca-operator && docker-compose run --rm cca-operator --help
```

Cca-operator mounts /etc/ckan-cloud directory from the host into the container

To use a different directory, create a .docker-compose.override.yaml file:

```
version: '3.2'
services:
  cca-operator:
    volumes:
    - /path/to/custom/etc-ckan-cloud:/etc/ckan-cloud
```

## Cluster Management

Follow the [ckan-cloud-helm developement quickstart](https://github.com/ViderumGlobal/ckan-cloud-helm/blob/master/QUICKSTART_DEVELOPMENT.md)
to create the cluster but don't create the CKAN namespace and don't deploy a CKAN instance.

Set the following in .docker-compose.override.yaml to mount your local kubeconfig into cca-operator

```
version: '3.2'
services:
  cca-operator:
    volumes:
    - /home/host-user-name/.kube:/root/.kube
    - /home/host-user-name/.minikube:/home/host-user-name/.minikube
    environment:
    - KUBE_CONTEXT=minikube
```

Verify that minikube is accessible via cca-operator

```
docker-compose run --rm --entrypoint kubectl cca-operator get nodes
```

Create a values file for the new instance:

```
INSTANCE_ID=test2
curl https://raw.githubusercontent.com/ViderumGlobal/ckan-cloud-helm/master/minikube-values.yaml \
    | tee /etc/ckan-cloud/${INSTANCE_ID}_values.yaml
```

Create the instance:

```
docker-compose build cca-operator && docker-compose run --rm cca-operator ./create-instance.sh $INSTANCE_ID
```

See the log output for accessing the instance

Get the list of available cca-operator cluster management commands:

```
docker-compose build cca-operator && docker-compose run --rm cca-operator
```


## CKAN Management

This procedure allows to test the cca-operator ckan management tasks, such as managing CKAN secrets

Follow the [ckan-cloud-helm developement quickstart](https://github.com/ViderumGlobal/ckan-cloud-helm/blob/master/QUICKSTART_DEVELOPMENT.md) to create the cluster and deploy a CKAN instance on it.

Set the namespace of the deployed instance

```
export CKAN_NAMESPACE=test1
```

Define a shortcut function for running cca-operator

```
cca-operator() {
    kubectl --context minikube --namespace ${CKAN_NAMESPACE} run cca-operator \
            --image=viderum/ckan-cloud-docker:cca-operator-latest \
            --serviceaccount=ckan-${CKAN_NAMESPACE}-operator --attach --restart=Never --rm \
            "$@"
}
```

Delete secrets to re-create

```
kubectl --context minikube -n $CKAN_NAMESPACE delete secret ckan-env-vars ckan-secrets
```

Run the cca-operator CKAN commands:

* create the ckan env vars secret: `cca-operator initialize-ckan-env-vars ckan-env-vars`
  * If you use the centralized infra, set the env vars: `--env CKAN_CLOUD_INSTANCE_ID=$CKAN_NAMESPACE --env CKAN_CLOUD_POSTGRES_HOST=db.ckan-cloud --env CKAN_CLOUD_POSTGRES_USER=postgres --env PGPASSWORD=123456 --env CKAN_CLOUD_SOLR_HOST=solr.ckan-cloud --env CKAN_CLOUD_SOLR_PORT=8983`
* Initialize the CKAN secrets.sh: `cca-operator initialize-ckan-secrets ckan-env-vars ckan-secrets`
* Write the CKAN secrets to secrets.sh: `cca-operator --command -- bash -c "./cca-operator.sh get-ckan-secrets ckan-secrets secrets.sh && cat secrets.sh"`


## cca-operator server

Add the ssh key to the server

```
cat docker-compose/cca-operator/id_rsa.pub | docker-compose run --rm cca-operator ./add-server-authorized-key.sh
```

Start the server

```
docker-compose up -d --build cca-operator
```

Run cca-operator commands via ssh

```
ssh -o IdentitiesOnly=yes -i docker-compose/cca-operator/id_rsa -p 8022 root@localhost ./cca-operator.sh ./list-instances.sh
```

## Creating a limited access user

Generate an SSH key for the limited user

```
ssh-keygen -t rsa -b 4096 -C "continuous-deployment" -N "" -f continuous-deployment-id_rsa
```

Add the key to cca-operator server authorized keys

```
CCA_OPERATOR_ROLE=continuous-deployment

cat continuous-deployment-id_rsa | docker-compose run --rm cca-operator ./add-server-authorized-key.sh "${CCA_OPERATOR_ROLE}"
```

The CCA_OPERATOR_ROLE environment variable is used in cca-operator code to limit access

## cca-operator

cca-operator runs as an initContainer on CKAN pods.

To test the cca-operator locally you need to be connected to a Kubernetes cluster

## Testing on Minikube

Build the image using Minikube docker-env - so the image will be available inside the Minikube cluster:

```
eval $(minikube docker-env) &&\
docker build -t uumpa/multi-ckan-cca-operator:latest cca-operator
```

Create a namespace and RBAC roles:

```
export CKAN_NAMESPACE="test1"

kubectl --context minikube create ns "${CKAN_NAMESPACE}" &&\
kubectl --context minikube --namespace "${CKAN_NAMESPACE}" \
    create serviceaccount "ckan-${CKAN_NAMESPACE}-operator" &&\
kubectl --context minikube --namespace "${CKAN_NAMESPACE}" \
    create role "ckan-${CKAN_NAMESPACE}-operator-role" --verb list,get,create \
                                                       --resource secrets &&\
kubectl --context minikube --namespace "${CKAN_NAMESPACE}" \
    create rolebinding "ckan-${CKAN_NAMESPACE}-operator-rolebinding" --role "ckan-${CKAN_NAMESPACE}-operator-role" \
                                                                     --serviceaccount "${CKAN_NAMESPACE}:ckan-${CKAN_NAMESPACE}-operator"
```

Define a shortcut function for running cca-operator

```
cca-operator() {
    kubectl --context minikube --namespace ${CKAN_NAMESPACE} run cca-operator \
            --image=uumpa/multi-ckan-cca-operator:latest \
            --serviceaccount=ckan-${CKAN_NAMESPACE}-operator --attach --restart=Never --rm \
            "$@"
}
```

Create the ckan env vars secret:

```
export ENV_VARS_SECRET_NAME="ckan-env-vars"

cca-operator initialize-ckan-env-vars "${ENV_VARS_SECRET_NAME}"
```

Initialize the CKAN secrets.sh:

```
export CKAN_SECRETS_SECRET_NAME="ckan-secrets"

cca-operator initialize-ckan-secrets "${ENV_VARS_SECRET_NAME}" "${CKAN_SECRETS_SECRET_NAME}"
```

Write the CKAN secrets to secrets.sh:

```
export SECRETS_SH_OUTPUT_FILE="/secrets.sh"

cca-operator --command -- bash -c \
    "./cca-operator.sh get-ckan-secrets ${CKAN_SECRETS_SECRET_NAME} ${SECRETS_SH_OUTPUT_FILE} && cat ${SECRETS_SH_OUTPUT_FILE}"
```

## cluster management

cca-operator supports certain cluster management tasks such as creting a new CKAN instance

Create instance (using interactive editor to set the values):

```
BASE_INSTANCE=demo4
NEW_INSTANCE=demo5

cp /etc/ckan-cloud/${BASE_INSTANCE}_values.yaml /etc/ckan-cloud/${NEW_INSTANCE}_values.yaml &&\
mcedit /etc/ckan-cloud/${NEW_INSTANCE}_values.yaml &&\
docker built -t cca-operator cca-operator &&\
docker run -v /etc/ckan-cloud:/etc/ckan-cloud cca-operator ./create-instance.sh ${NEW_INSTANCE}
```

Delete instance:

```
DELETE_INSTANCE=demo4

docker run -v /etc/ckan-cloud:/etc/ckan-cloud cca-operator ./delete-instance.sh ${DELETE_INSTANCE}
```

List instances:

```
docker run -v /etc/ckan-cloud:/etc/ckan-cloud cca-operator ./list-instances.sh
```

Update instance (using interactive editor):

```
UPDATE_INSTANCE=demo3

mcedit /etc/ckan-cloud/${UPDATE_INSTANCE}_values.yaml &&\
docker build -t cca-operator cca-operator &&\
docker run -v /etc/ckan-cloud:/etc/ckan-cloud cca-operator ./update-instance.sh ${UPDATE_INSTANCE}
```

List available cca-operator cluster commands:

```
docker build -t cca-operator cca-operator &&\
docker run -v /etc/ckan-cloud:/etc/ckan-cloud cca-operator --help
```

#!/usr/bin/env bash

# Migrate the data from S3 FileStorage to local fyle system

# FileStorage Server Eg: https://cc-p-minio.ckan.io or https://s3.amazonaws.com
HOST=${1}
ACCESS_KEY=${2}
SECRET_KEY=${3}
BUCKET=${4}
STORAGE_PREFIX=${5}/
TMP_DATA_RECEIVED='/tmp/data_received'
TMP_DATA='/tmp/data'

# Download minio client
wget https://dl.min.io/client/mc/release/linux-amd64/mc && chmod +x mc
# Add host
./mc config host add filestorage $HOST $ACCESS_KEY $SECRET_KEY
echo downloading from storage
./mc cp --recursive filestorage/$BUCKET/$STORAGE_PREFIX $TMP_DATA_RECEIVED

echo updating paths
for dir in $(ls $TMP_DATA_RECEIVED/resources); do
  FIRST_DIR=${dir:0:3}
  SECOND_DIR=${dir:3:3}
  REST=${dir:6}
  RESOURCE_DIR=$TMP_DATA/resources/$FIRST_DIR/$SECOND_DIR
  mkdir -p $RESOURCE_DIR
  for file in $TMP_DATA_RECEIVED/resources/$dir/*; do
    echo $file
    cp $file $RESOURCE_DIR/$REST
  done
done
cp -r $TMP_DATA_RECEIVED/storage $TMP_DATA/storage

echo mounting data into the persistent volumes
docker cp $TMP_DATA ckan-cloud-docker_ckan_1:/var/lib/ckan
docker-compose -f docker-compose.yaml -f .docker-compose-db.yaml -f .docker-compose.${5}-theme.yaml exec -u root ckan chown -R ckan:ckan /var/lib/ckan

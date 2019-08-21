#!/usr/bin/env bash                                                                                                                            
                                                                                                                                               
DB_BACKUP=${1}                                                                                                                                 
DATASTORE_DB_BACKUP=${2}                                                                                                                       
ROOT_DB=${3}                                                                                                                                   
INSTANCE_ID=${4}                                                                                                                               
                                                                                                                                               
# recover DB                                                                                                                                   
if [ "$DB_BACKUP" != "" ]; then                                                                                                                
  wget -O db_backup.gz $DB_BACKUP && gunzip db_backup.gz                                                                                       
  psql $ROOT_DB -c "SELECT pg_terminate_backend (pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = '$INSTANCE_ID'"  
  psql $ROOT_DB -c "DROP DATABASE $INSTANCE_ID;"                                                                                               
  psql $ROOT_DB -c "CREATE DATABASE $INSTANCE_ID;"                                                                                             
  psql $CKAN_SQLALCHEMY_URL -f db_backup $INSTANCE_ID                                                                                          
  psql $ROOT_DB/$INSTANCE_ID -c "CREATE EXTENSION postgis;"                                                                                    
  psql $ROOT_DB/$INSTANCE_ID -c "CREATE EXTENSION postgis_topology;"                                                                           
fi                                                                                                                                             
                                                                                                                                               
# recover datastore DB                                                                                                                         
if [ "$DATASTORE_DB_BACKUP" != "" ]; then                                                                                                      
  wget -O db_datastore_backup.gz $DATASTORE_DB_BACKUP && gunzip db_datastore_backup.gz                                                         
  psql $ROOT_DB -c "SELECT pg_terminate_backend (pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = '$INSTANCE_ID-datastore'"
  psql $ROOT_DB -c "DROP DATABASE $INSTANCE_ID-datastore;"                                                                                     
  psql $ROOT_DB -c "CREATE DATABASE $INSTANCE_ID-datastore;"                                                                                   
  psql $CKAN__DATASTORE__WRITE_URL -f db_datastore_backup $INSTANCE_ID-datastore                                                               
fi

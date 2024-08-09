#!/bin/bash
  
# turn on bash's job control
set -m

check_db_ready() {
  (echo > /dev/tcp/datastore-db/5432) >/dev/null 2>&1
}

until check_db_ready; do
  echo "Waiting for datastore-db to be ready..."
  sleep 2
done

echo "datastore-db is ready. Starting datapusher..."

# Start the primary process and put it in the background
${VENV}/bin/uwsgi --socket=/tmp/uwsgi.sock --enable-threads -i ${CFG_DIR}/uwsgi.ini --wsgi-file=${SRC_DIR}/datapusher-plus/wsgi.py &

# Start the test process
#cd ${SRC_DIR}/testing-datapusher-plus && ${VENV}/bin/python test.py

fg %1

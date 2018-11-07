echo "Setting up datastore permissions cron" &&\
mkdir -p /datastore-permissions-crontabs &&\
echo '* * * * * bash /db-scripts/datastore-permissions-update.sh' > /datastore-permissions-crontabs/root
[ "$?" != "0" ] && echo failed to initialize datastore permissions cron && exit 1
exec crond -f -L /dev/stdout -c /datastore-permissions-crontabs

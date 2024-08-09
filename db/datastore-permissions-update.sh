cd /
while ! su postgres -c "pg_isready"; do echo waiting for DB..; sleep 1; done
[ `su postgres -c "psql -c \"select count(1) from pg_roles where rolname='readonly'\" -tA"` == "0" ] &&\
    echo creating role readonly &&\
    ! su postgres -c "psql -c \"create role readonly with login password '${DATASTORE_PUBLIC_RO_PASSWORD}';\"" \
        && echo failed to create readonly role && exit 1
echo getting all datastore resource ids
! DATASTORE_RESOURCES=`su postgres -c 'psql datastore -c "select tablename from pg_tables where schemaname='"'public'"';" -tA'` \
    && echo failed to get datastore tables && exit 1
echo updating datastore table permissions
for RESOURCE in $DATASTORE_RESOURCES; do
    if wget -qO /dev/null http://ckan:5000/api/3/action/resource_show?id=${RESOURCE} 2>/dev/null; then
        ! su postgres -c "psql datastore -c 'grant select on \"${RESOURCE}\" to readonly;'" >/dev/null &&\
            echo failed to grant select permissions for readonly on ${RESOURCE}
    else
        ! su postgres -c "psql datastore -c 'revoke select on \"${RESOURCE}\" from readonly;'" >/dev/null &&\
            echo failed to revoke select permission for readonly on ${RESOURCE}
    fi
done

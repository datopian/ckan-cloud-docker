\connect "ckan"

GRANT CREATE ON SCHEMA public TO "ckan";
GRANT USAGE ON SCHEMA public TO "ckan";

-- take connect permissions from main db
REVOKE CONNECT ON DATABASE "ckan" FROM "readonly";
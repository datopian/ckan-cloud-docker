#!/usr/bin/env python
import glob
import os
import re
import sys
import uuid

if sys.version_info[0] < 3:
    input = raw_input

current_dir = os.path.dirname(os.path.realpath(__file__))
write_secrets = {}


def set_databse_urls(secrets):
    write_secrets['ckan'].append(
        'export SQLALCHEMY_URL=postgresql://ckan:{db_password}@db/ckan'.format(
            db_password=secrets['db-POSTGRES_PASSWORD']
    ))
    write_secrets['ckan'].append(
        'export CKAN_DATASTORE_WRITE_URL=postgresql://postgres:{datastore_password}@datastore-db/datastore'.format(
            datastore_password = secrets['datastore-db-DATASTORE_PASSWORD']
    ))
    write_secrets['ckan'].append(
        'export CKAN_DATASTORE_READ_URL=postgresql://{ro_user}:{ro_password}@datastore-db/datastore'.format(
        ro_user=secrets['datastore-db-DATASTORE_RO_USER'],
        ro_password=secrets['datastore-db-DATASTORE_RO_PASSWORD']
    ))

def main():
    print('The script will create or update (if it is already exists) local secrets files.\n')

    filename = os.path.join(current_dir, 'docker-compose', 'ckan-secrets.dat')
    secrets_filenames = os.path.join(current_dir, 'docker-compose', '*-secrets.sh')
    spec = open(filename, 'r').readlines()
    secrets = {}

    for filename in glob.glob(secrets_filenames):
        secrets_lines = open(filename, 'r').readlines()
        secrets_for = filename.split('/')[-1].replace('-secrets.sh', '')
        for secret in secrets_lines:
            idx = 1 if secrets_for == 'ckan' else 0
            name, value = secret.split()[idx].split('=')
            secrets['{}-{}'.format(secrets_for, name)] = value

    for i, line in enumerate(spec):
        secrets_for, mode, name, default, description = line.split(' ', 4)
        saved_value = secrets.get('{}-{}'.format(secrets_for, name))

        if name == 'BEAKER_SESSION_SECRET' or name == 'APP_INSTANCE_UUID':
            default = str(uuid.uuid4())
        if saved_value:
            example = 'Skip to use saved value "{}"'.format(saved_value)
        else:
            example = 'Default value "{}"'.format(default)


        value = input('[{}] {} \n({}): '.format(
            i + 1,
            description.strip('\n'),
            example
        ))
        if not value and saved_value:
            value = saved_value

        if value is None:
            value = ''
        else:
            value = value.strip()

        if not value and mode == 'required':
            print('Used default value: {}'.format(default))
            value = default

        if not value and mode == 'optional':
            value = ''

        if secrets_for not in write_secrets:
            write_secrets[secrets_for] = []


        prefix = 'export ' if secrets_for == 'ckan' else ''
        write_secrets[secrets_for].append('{}{}={}'.format(prefix, name, value))
        print('')
        secrets['{}-{}'.format(secrets_for, name)] = value


    set_databse_urls(secrets)
    save_values()


def save_values():
    for filename, write_secret in write_secrets.items():
        secrets_filename = os.path.join(current_dir, 'docker-compose', '%s-secrets.sh' % filename)
        with open(secrets_filename, 'w') as f:
            f.write('\n'.join(write_secret))
            print('Saved {}'.format(secrets_filename))


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        value = input('\n\nSave entered values (old non-entered values from secrets file will be also removed)? [y/N]: ')
        if value == 'y':
            save_values()
        else:
            print('\nExiting without saving')

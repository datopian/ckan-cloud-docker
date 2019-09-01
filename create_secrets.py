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


def set_parsed_values(secrets, secrets_for, name, value):
    if secrets_for == 'ckan' and name == 'CKAN_DATASTORE_READ_URL':
        res = re.findall(r'postgresql://([-_A-Za-z0-9]+):([^@]+)@datastore-db', value)
        if not res:
            return
        user, password = res[0]
        secrets['datastore-db-DATASTORE_RO_PASSWORD'] = password
        secrets['datastore-db-DATASTORE_RO_USER'] = user
        secrets['datastore-db-DATASTORE_PUBLIC_RO_PASSWORD'] = password

    if secrets_for == 'db' and name == 'POSTGRES_PASSWORD':
        secrets['datastore-db-POSTGRES_PASSWORD'] = value
        secrets['provisioning-api-db-POSTGRES_PASSWORD'] = value


def main():
    print('The script will create or update (if it is already exists) local secrets files.\n')

    filename = os.path.join(current_dir, 'docker-compose', 'ckan-secrets.dat')
    secrets_filenames = os.path.join(current_dir, 'docker-compose', '*-secrets.sh')
    spec = open(filename, 'r').readlines()

    secrets = {}
    for filename in glob.glob(secrets_filenames):
        secrets_lines = open(filename, 'r').readlines()
        secrets_for = filename.split('/')[-1].replace('-secrets.sh', '')
        if secrets_for in ('datastore-db', 'provisioning-api-db'):
            continue
        for secret in secrets_lines:
            idx = 1 if secrets_for == 'ckan' else 0
            name, value = secret.split()[idx].split('=')
            secrets['{}-{}'.format(secrets_for, name)] = value
            set_parsed_values(secrets, secrets_for, name, value)

    for i, line in enumerate(spec):
        secrets_for, mode, name, default, description = line.split(' ', 4)
        saved_value = secrets.get('{}-{}'.format(secrets_for, name))

        if name == 'BEAKER_SESSION_SECRET' or name == 'APP_INSTANCE_UUID':
            default = uuid.uuid4()
        if saved_value:
            example = 'Skip to use saved value "{}"'.format(saved_value)
        else:
            example = 'Default value "{}"'.format(default)

        if secrets_for in ('datastore-db', 'provisioning-api-db'):
            value = saved_value
            print('[{}] Used parsed value for {}, {} container: {}'.format(
                i + 1,
                name,
                secrets_for,
                value
            ))
        else:
            value = input('[{}] Enter {} value for {}, {} container [{}].\n({}): '.format(
                i + 1,
                description.strip('\n'),
                name,
                secrets_for,
                mode,
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

        set_parsed_values(secrets, secrets_for, name, value)

        prefix = 'export ' if secrets_for == 'ckan' else ''
        write_secrets[secrets_for].append('{}{}={}'.format(prefix, name, value))
        print('')

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

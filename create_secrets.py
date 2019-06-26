#!/usr/bin/env python
import glob
import os
import sys

if sys.version_info[0] < 3:
    input = raw_input

current_dir = os.path.dirname(os.path.realpath(__file__))


def main():
    print('The script will create or update (if it is already exists) local secrets files.\n')

    filename = os.path.join(current_dir, 'docker-compose', 'ckan-secrets.spec')
    secrets_filenames = os.path.join(current_dir, 'docker-compose', '*-secrets.sh')
    spec = open(filename, 'r').readlines()

    secrets = {}
    write_secrets = {}
    for filename in glob.glob(secrets_filenames):
        secrets_lines = open(filename, 'r').readlines()
        secrets_for = filename.split('/')[-1].replace('-secrets.sh', '')
        for secret in secrets_lines:
            name, value = secret.split()[1].split('=')
            secrets['{}-{}'.format(secrets_for, name)] = value

    for i, line in enumerate(spec):
        secrets_for, mode, name, example, description = line.split(' ', 4)
        saved_value = secrets.get('{}-{}'.format(secrets_for, name))
        if saved_value:
            example = 'Skip to use saved value "{}"'.format(saved_value)
        else:
            example = 'Sample value "{}"'.format(example)

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

        while not value and mode == 'required':
            value = input('Value for {} could not be empty. Enter value: '.format(name))

        if secrets_for not in write_secrets:
            write_secrets[secrets_for] = []
        write_secrets[secrets_for].append('export {}={}'.format(name, value))
        print('')

    for filename, write_secret in write_secrets.items():
        secrets_filename = os.path.join(current_dir, 'docker-compose', '%s-secrets.sh' % filename)
        with open(secrets_filename, 'w') as f:
            f.write('\n'.join(write_secret))
            print('Saved {}'.format(secrets_filename))


if __name__ == '__main__':
    main()

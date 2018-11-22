#!/usr/bin/env python3
import os, sys, yaml, datetime


CCA_OPERATOR_ROLE = os.environ['CCA_OPERATOR_ROLE']


ADMIN_ROLES = ['', 'admin']
CONTINUOUS_DEPLOYMENT_ROLES = ADMIN_ROLES + ['continuous-deployment']


def print_stderr(*args):
    print(*args, file=sys.stderr)


if sys.argv[1].startswith('patch-deployment ') and CCA_OPERATOR_ROLE in CONTINUOUS_DEPLOYMENT_ROLES:
    _, namespace, deployment, container, values_file, backup_dir, image_attrib, image = sys.argv[1].split(' ')
    with open(values_file) as f:
        values = yaml.load(f)
    os.system(f'mkdir -p {backup_dir}')
    backup_file = 'values_' + datetime.datetime.now().strftime('%Y-%m-%d_%H_%M_%s') + '.yaml'
    backup_file = os.path.join(backup_dir, backup_file)
    print_stderr(f'modifying values file {values_file}, saving backup to {backup_file}')
    with open(backup_file, 'w') as f:
        yaml.dump(values, f)
    values[image_attrib] = image
    with open(values_file, 'w') as f:
        yaml.dump(values, f)
    if deployment != '' and container != '':
        patch_params = f'deployment/{deployment} {container}={image}'
        print_stderr(f'patching {patch_params}')
        patch_cmd = f'kubectl set image -n {namespace} {patch_params}'
        if os.system(f'{patch_cmd} --dry-run') != 0:
            print_stderr('dry-run failed')
            exit(1)
        if os.system(f'{patch_cmd}') != 0:
            print_stderr('failed to patch deployment')
            exit(1)
    print_stderr('Great Success!')
    exit(0)
else:
    print_stderr('Unexpected Error')
    exit(1)

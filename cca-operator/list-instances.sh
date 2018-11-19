#!/usr/bin/env bash

[ "${1}" == "--help" ] && echo ./list-instances.sh && exit 0

source functions.sh
! kubectl_init && exit 1

kubectl $KUBECTL_GLOBAL_ARGS get pods -l app=ckan --all-namespaces -o yaml \
    | python3 -c '

import yaml, sys, glob

pod_phases = {}

for pod in yaml.load(sys.stdin)["items"]:
    if pod["status"]["phase"] != "Running":
        pod_phase = pod["status"]["phase"]
        pod_active = False
    elif not pod["status"]["containerStatuses"][0]["ready"]:
        pod_phase = "not ready"
        pod_active = False
    else:
        pod_phase = pod["status"]["phase"]
        pod_active = True

    instance_id = pod["metadata"]["namespace"]
    pod_phases[instance_id] = {
        "ckanPhase": pod_phase,
        "active": pod_active,
        "valuesFile": f"/etc/ckan-cloud/{instance_id}_values.yaml"
    }

values_files = [p["valuesFile"] for p in pod_phases.values()]

values_without_pod = []
for values_file in glob.glob("/etc/ckan-cloud/*_values.yaml"):
    if values_file not in values_files:
        values_without_pod.append(values_file)

print("# pod_phases")
print(yaml.dump(pod_phases, default_flow_style=False))
print("------")
print("# value files without pod")
print(yaml.dump(values_without_pod, default_flow_style=False))

    '

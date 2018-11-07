#!/usr/bin/env bash

export KUBECONFIG=/etc/ckan-cloud/.kube-config

kubectl get pods -l app=ckan --all-namespaces -o yaml \
    | python3 -c '
import yaml, sys
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
    pod_phases[pod["metadata"]["namespace"]] = {"ckanPhase": pod_phase, "active": pod_active}
print(yaml.dump(pod_phases, default_flow_style=False))
    '

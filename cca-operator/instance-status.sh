#!/usr/bin/env bash

[ "${1}" == "--help" ] && echo ./instance-status.sh '<INSTANCE_ID>' && exit 0

source functions.sh
! cluster_management_init "${1}" && exit 1

if [ -e _instance_status_pods.yaml ]; then
    echo using cached copy from `pwd`/_instance_status_pods.yaml - delete to recreate
    PODS=`cat _instance_status_pods.yaml`
else
    PODS=`instance_kubectl get all -o yaml`
fi

# for development
# echo "${PODS}" > _instance_status_pods.yaml

echo "${PODS}" | python3 -c '

import yaml, sys, os, datetime, subprocess, json
from collections import OrderedDict

def item_detailed_status(kind, name, app, item):
    item_status = {"name": name, "created_at": item["metadata"]["creationTimestamp"], "true_status_last_transitions": {}}
    if kind in ["Deployment", "ReplicaSet"]:
        item_status["generation"] = item["metadata"]["generation"]
    for condition in item["status"].get("conditions", []):
        assert condition["type"] not in item_status["true_status_last_transitions"]
        if condition["status"] == "True":
            item_status["true_status_last_transitions"][condition["type"]] = condition["lastTransitionTime"]
        else:
            item_status.setdefault("errors", []).append({
                "kind": "failed_condition",
                "status": condition["status"],
                "reason": condition["reason"],
                "message": condition["message"],
                "last_transition": condition["lastTransitionTime"]
            })
    if kind == "Pod" and app == "ckan":
        for container in ["secrets", "ckan"]:
            container_logs = subprocess.run("kubectl -n {} logs {} -c {}".format(os.environ["INSTANCE_NAMESPACE"], name, container),
                                            stderr=subprocess.STDOUT, stdout=subprocess.PIPE, shell=True).stdout
            for logline in container_logs.decode().split("--START_CKAN_CLOUD_LOG--")[1:]:
                logdata = json.loads(logline.split("--END_CKAN_CLOUD_LOG--")[0])
                item_status.setdefault("ckan-cloud-logs", []).append(logdata)
    return item_status

status = {}
for item in yaml.load(sys.stdin)["items"]:
    kind = item["kind"]
    name = item["metadata"]["name"]
    if kind in ["Pod", "Deployment", "ReplicaSet"]:
        app = item["metadata"]["labels"]["app"]
    elif kind == "Service":
        app = item["metadata"]["name"]
    else:
        app = None
    if app in ["ckan", "jobs-db", "redis", "nginx", "jobs"]:
        app_status = status.setdefault(app, {})
    else:
        app_status = status.setdefault("unknown", {})
    item_status = item_detailed_status(kind, name, app, item)
    app_status.setdefault("{}s".format(kind.lower()), []).append(item_status)

print(yaml.dump(status, default_flow_style=False))
print("---")
print(yaml.dump({
    "ckan_instance_id": os.environ["INSTANCE_ID"],
    "namespace": os.environ["INSTANCE_NAMESPACE"],
    "status_generated_at": datetime.datetime.now(),
    "status_generated_from": subprocess.check_output("hostname").decode().strip()
}, default_flow_style=False))
'

#!/usr/bin/env python3
import argparse
import json
import os
import re
import subprocess
import sys

parser = argparse.ArgumentParser()
parser.add_argument("--prefix", required=True)
parser.add_argument("--developers", required=True)
args = parser.parse_args()

def run(command, environment=None):
    process_environment = os.environ.copy()
    if environment:
        process_environment.update(environment)
    result = subprocess.run(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True,
        env=process_environment,
    )
    return result.returncode, result.stdout.strip(), result.stderr.strip()

failures = []
for slug in [x for x in args.developers.split(",") if x]:
    project = "prj-{}-{}".format(args.prefix, slug)
    expected = [
        "vm-{}-{}-db".format(args.prefix, slug),
        "vm-{}-{}-app1".format(args.prefix, slug),
        "vm-{}-{}-app2".format(args.prefix, slug),
    ]
    rc, output, error = run(["openstack", "--os-project-name", project, "server", "list", "-f", "json"])
    if rc:
        failures.append("{}: server list failed: {}".format(slug, error))
        continue
    servers = json.loads(output or "[]")
    names = {item.get("Name") for item in servers}
    missing = [name for name in expected if name not in names]
    if missing:
        failures.append("{}: missing {}".format(slug, ", ".join(missing)))
    else:
        print("[PASS] {}: DB + 2 app VM instances".format(slug))

    server_by_name = {item.get("Name"): item for item in servers}
    not_active = [
        name for name in expected
        if name in server_by_name and server_by_name[name].get("Status") != "ACTIVE"
    ]
    if not_active:
        failures.append("{}: non-ACTIVE instances: {}".format(slug, ", ".join(not_active)))

    rc, output, error = run(["openstack", "--os-project-name", project, "loadbalancer", "show", "lb-{}-{}".format(args.prefix, slug), "-f", "value", "-c", "provisioning_status"])
    if rc or output != "ACTIVE":
        failures.append("{}: load balancer is not ACTIVE ({})".format(slug, error or output))
    else:
        print("[PASS] {}: Octavia load balancer ACTIVE".format(slug))

    rc, output, error = run(["openstack", "--os-project-name", project, "container", "show", "obj-{}-{}-moodle".format(args.prefix, slug)])
    if rc:
        failures.append("{}: Swift container missing".format(slug))
    else:
        print("[PASS] {}: private Swift container".format(slug))

    rc, output, error = run(
        ["manila", "show", "share-{}-{}-backup".format(args.prefix, slug)],
        {"OS_PROJECT_NAME": project, "OS_TENANT_NAME": project},
    )
    if rc or not re.search(r"\|\s*status\s*\|\s*available\s*\|", output, re.IGNORECASE):
        failures.append("{}: Manila share is not available ({})".format(slug, error or output))
    else:
        print("[PASS] {}: Manila CephFS share available".format(slug))

rc, output, error = run([
    "openstack", "--os-project-name", "prj-{}-lead".format(args.prefix),
    "server", "show", "vm-{}-lead-jump".format(args.prefix),
    "-f", "value", "-c", "status",
])
if rc or output != "ACTIVE":
    failures.append("Team Lead jump host is not ACTIVE ({})".format(error or output))
else:
    print("[PASS] Team Lead jump host ACTIVE")

if failures:
    for failure in failures:
        print("[FAIL] " + failure)
    sys.exit(1)

print("[PASS] TECHSPRINT_OPENSTACK_DEPLOYMENT")

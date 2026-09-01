#!/usr/bin/env python3
import argparse
import json
import subprocess
import sys

parser = argparse.ArgumentParser()
parser.add_argument("--prefix", required=True)
parser.add_argument("--developers", required=True)
args = parser.parse_args()

def run(command):
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
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
    names = {item.get("Name") for item in json.loads(output or "[]")}
    missing = [name for name in expected if name not in names]
    if missing:
        failures.append("{}: missing {}".format(slug, ", ".join(missing)))
    else:
        print("[PASS] {}: DB + 2 app VM instances".format(slug))

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

rc, output, error = run(["openstack", "--os-project-name", "prj-{}-lead".format(args.prefix), "server", "show", "vm-{}-lead-jump".format(args.prefix)])
if rc:
    failures.append("Team Lead jump host missing")
else:
    print("[PASS] Team Lead jump host exists")

if failures:
    for failure in failures:
        print("[FAIL] " + failure)
    sys.exit(1)

print("[PASS] TECHSPRINT_OPENSTACK_DEPLOYMENT")


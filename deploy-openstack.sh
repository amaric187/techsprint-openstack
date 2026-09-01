#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CSV_PATH="${1:-}"
RUNTIME_DIR="$ROOT_DIR/runtime"
CONFIG_PATH="$RUNTIME_DIR/config.json"
SECRETS_PATH="$RUNTIME_DIR/secrets.json"
CREDENTIALS_PATH="$RUNTIME_DIR/credentials.csv"
SSH_KEY_PATH="$RUNTIME_DIR/lead_ssh"

fail() {
  echo "[ERROR] $*" >&2
  exit 1
}

[[ -n "$CSV_PATH" ]] || fail "Upotreba: ./deploy-openstack.sh /putanja/users.csv"
[[ -f "$CSV_PATH" ]] || fail "CSV ne postoji: $CSV_PATH"
[[ -n "${OS_AUTH_URL:-}" && -n "${OS_USERNAME:-}" && -n "${OS_PASSWORD:-}" ]] || \
  fail "Prvo pokreni: source ~/overcloudrc"

for command_name in ansible-playbook openstack manila python3 ssh-keygen; do
  command -v "$command_name" >/dev/null 2>&1 || fail "Nedostaje naredba: $command_name"
done

mkdir -p "$RUNTIME_DIR"
chmod 700 "$RUNTIME_DIR"

if [[ ! -f "$SSH_KEY_PATH" ]]; then
  ssh-keygen -q -t rsa -b 3072 -N '' -C 'techsprint-lead' -f "$SSH_KEY_PATH"
fi
chmod 600 "$SSH_KEY_PATH"
chmod 644 "$SSH_KEY_PATH.pub"

python3 - "$CSV_PATH" "$SECRETS_PATH" "$CONFIG_PATH" "$CREDENTIALS_PATH" "$SSH_KEY_PATH.pub" <<'PY'
import csv
import json
import os
import re
import secrets
import string
import sys
import unicodedata

csv_path, secrets_path, config_path, credentials_path, public_key_path = sys.argv[1:]

def slugify(value):
    normalized = unicodedata.normalize("NFKD", value)
    ascii_value = normalized.encode("ascii", "ignore").decode("ascii")
    return re.sub(r"[^a-z0-9]+", "-", ascii_value.lower()).strip("-")

def password():
    alphabet = string.ascii_letters + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(28))

with open(csv_path, "r", encoding="utf-8-sig", newline="") as handle:
    sample = handle.read(4096)
    handle.seek(0)
    delimiter = ";" if sample.count(";") >= sample.count(",") else ","
    reader = csv.DictReader(handle, delimiter=delimiter)
    required = {"ime", "prezime", "rola"}
    if not reader.fieldnames or not required.issubset(set(reader.fieldnames)):
        raise SystemExit("CSV mora sadržavati stupce: ime, prezime, rola")
    rows = list(reader)

if not rows:
    raise SystemExit("CSV nema korisnika")

if os.path.exists(secrets_path):
    with open(secrets_path, "r", encoding="utf-8") as handle:
        saved = json.load(handle)
else:
    saved = {"users": {}, "storage": {}, "database": {}}

users = []
for row in rows:
    first = (row.get("ime") or "").strip()
    last = (row.get("prezime") or "").strip()
    role = (row.get("rola") or "").strip().lower()
    if role not in {"developer", "devops_lead"}:
        raise SystemExit("Nepodržana rola za {} {}: {}".format(first, last, role))
    slug = slugify("{}-{}".format(first, last))
    if not slug:
        raise SystemExit("Nije moguće napraviti slug za {} {}".format(first, last))
    saved["users"].setdefault(slug, password())
    user = {
        "first_name": first,
        "last_name": last,
        "display_name": "{} {}".format(first, last),
        "slug": slug,
        "role": role,
        "email": (row.get("upn") or "{}@example.invalid".format(slug)).strip(),
        "username": "usr-techsprint-tst-{}".format(slug),
        "password": saved["users"][slug],
    }
    if role == "developer":
        saved["storage"].setdefault(slug, password())
        saved["database"].setdefault(slug, password())
        user["storage_username"] = "svc-techsprint-tst-{}-swift".format(slug)
        user["storage_password"] = saved["storage"][slug]
        user["database_password"] = saved["database"][slug]
    users.append(user)

leads = [u for u in users if u["role"] == "devops_lead"]
developers = [u for u in users if u["role"] == "developer"]
if len(leads) != 1:
    raise SystemExit("CSV mora sadržavati točno jednog devops_lead korisnika")
if not developers:
    raise SystemExit("CSV mora sadržavati barem jednog developera")
if len({u["slug"] for u in users}) != len(users):
    raise SystemExit("Korisnici moraju imati jedinstvenu kombinaciju imena i prezimena")

with open(public_key_path, "r", encoding="utf-8") as handle:
    public_key = handle.read().strip()

config = {
    "prefix": "techsprint-tst",
    "environment_name": "testing",
    "external_network": "provider-datacentre",
    "app_image": "rhel8-web",
    "db_image": "rhel8-db",
    "lead_image": "rhel8",
    "flavor_name": "flv-techsprint-app",
    "volume_type": "tripleo",
    "share_type": "techsprint-cephfs",
    "share_backend": "cephfs",
    "lead": leads[0],
    "developers": developers,
    "all_users": users,
    "lead_public_key": public_key,
}

for path, data in ((secrets_path, saved), (config_path, config)):
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
    os.chmod(path, 0o600)

with open(credentials_path, "w", encoding="utf-8", newline="") as handle:
    writer = csv.writer(handle, delimiter=";")
    writer.writerow(["display_name", "role", "openstack_username", "openstack_password"])
    for user in users:
        writer.writerow([user["display_name"], user["role"], user["username"], user["password"]])
os.chmod(credentials_path, 0o600)
PY

export ANSIBLE_CONFIG="$ROOT_DIR/ansible.cfg"
echo "[INFO] Provjeravam Ansible sintaksu..."
ansible-playbook "$ROOT_DIR/playbooks/deploy.yml" \
  --syntax-check \
  --extra-vars "@$CONFIG_PATH" \
  --extra-vars "runtime_dir=$RUNTIME_DIR"

echo "[INFO] Pokrećem TechSprint OpenStack deployment..."
ansible-playbook "$ROOT_DIR/playbooks/deploy.yml" \
  --extra-vars "@$CONFIG_PATH" \
  --extra-vars "runtime_dir=$RUNTIME_DIR"

echo
echo "[PASS] Deployment je završen."
echo "[INFO] Lokalni korisnički podaci: $CREDENTIALS_PATH"
echo "[INFO] Datoteke u runtime/ nisu namijenjene za Git."

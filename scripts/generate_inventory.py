#!/usr/bin/env python3

import json
import argparse
import ipaddress
import re
from pathlib import Path

parser = argparse.ArgumentParser(
    description="Generate Ansible inventory from Terraform outputs"
)
parser.add_argument("terraform_outputs")
args = parser.parse_args()

with open(args.terraform_outputs) as file:
    outputs = json.load(file)

monitor_public = str(ipaddress.IPv4Address(
    outputs["monitor_public_ip"]["value"]
))
monitor_private = str(ipaddress.IPv4Address(
    outputs["monitor_private_ip"]["value"]
))
client_private = str(ipaddress.IPv4Address(
    outputs["client_private_ip"]["value"]
))
username = outputs["admin_username"]["value"]

if not re.fullmatch(r"[a-z_][a-z0-9_-]*", username):
    raise ValueError("Invalid SSH username")

inventory = f"""[monitor]
g3-monitor ansible_host={monitor_public}

[client]
g3-client ansible_host={client_private}

[all:vars]
ansible_user={username}
ansible_ssh_private_key_file=~/.ssh/nssa320_g3
monitor_private_ip={monitor_private}
client_private_ip={client_private}

[client:vars]
ansible_ssh_common_args='-o ProxyJump=g3-monitor'
"""

root = Path(__file__).resolve().parents[1]
destination = root / "ansible/inventory/generated.ini"

destination.parent.mkdir(parents=True, exist_ok=True)
destination.write_text(inventory)
destination.chmod(0o600)

print(f"Inventory generated: {destination}")

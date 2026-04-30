# Hetzner Cloud — primary failover target
#
# Defaults: CAX31 (4 vCPU ARM Ampere / 8 GB / 160 GB NVMe / €14/mo) in hel1.
# Matches hetz-1's existing layout for ARM continuity. To switch:
#   - x86: change server_type to "cpx31" (same specs but Intel/AMD)
#   - region: change location to "fsn1" (Falkenstein), "nbg1" (Nuremberg),
#             or "ash" (Ashburn, US East — where midpen workers live)
#
# Auth: HCLOUD_TOKEN env var. Operator ships hetzner-tokens.enc → decrypted
# to /etc/hcloud/cli.toml by setup.sh::materialize_secrets, OR exports
# HCLOUD_TOKEN directly when running from a host that already has the
# plaintext (e.g. wallypad: token lives in ~/.config/hcloud/cli.toml).
#
# Tested with terraform 1.10.3, hcloud provider 1.49.x.

terraform {
  required_version = ">= 1.5"
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.49"
    }
  }
}

provider "hcloud" {
  # token from HCLOUD_TOKEN env var
}

resource "hcloud_ssh_key" "operator" {
  name       = "operator-${var.vm_hostname}"
  public_key = file("~/.ssh/id_ed25519.pub")
}

resource "hcloud_server" "joppa" {
  name        = var.vm_hostname
  image       = "ubuntu-24.04"
  server_type = "cax31" # ARM (Ampere). Change to "cpx31" for x86.
  location    = "hel1"  # Helsinki. See header for alternatives.
  ssh_keys    = [hcloud_ssh_key.operator.id]

  user_data = templatefile("${path.module}/../bootstrap/cloud-init.yaml", {
    tailscale_auth_key = var.tailscale_auth_key
    hostname           = var.vm_hostname
  })

  labels = {
    role    = "joppa-primary"
    managed = "dr-bootstrap"
    vendor  = "hetzner"
  }

  # Don't recreate the server on cloud-init / SSH-key changes — those need
  # explicit operator action (re-bootstrap), not silent destroy/recreate.
  lifecycle {
    ignore_changes = [user_data, ssh_keys]
  }
}

output "joppa_ipv4" {
  description = "Public IPv4 of the new joppa primary"
  value       = hcloud_server.joppa.ipv4_address
}

output "joppa_ipv6" {
  description = "Public IPv6 of the new joppa primary"
  value       = hcloud_server.joppa.ipv6_address
}

output "joppa_status" {
  description = "Hetzner-reported status (running / starting / off)"
  value       = hcloud_server.joppa.status
}

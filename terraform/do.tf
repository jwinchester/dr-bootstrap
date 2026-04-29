# DigitalOcean — primary backup failover target (cold, provisioned on-demand)
#
# TODO: requires DIGITALOCEAN_TOKEN env var. Token created at
#       https://cloud.digitalocean.com/account/api/tokens (full Read+Write).
#
# When live, this provisions a Standard-4GB ($24/mo, $0.0357/hr) in any
# region — choose nyc3/sfo3/fra1 based on Tailscale RTT.

# terraform {
#   required_providers {
#     digitalocean = {
#       source  = "digitalocean/digitalocean"
#       version = "~> 2.40"
#     }
#   }
# }
#
# provider "digitalocean" {
#   # token from DIGITALOCEAN_TOKEN env var
# }
#
# resource "digitalocean_droplet" "joppa" {
#   name      = var.vm_hostname
#   image     = "ubuntu-24-04-x64"
#   size      = "s-2vcpu-4gb"
#   region    = "sfo3"
#   ssh_keys  = [digitalocean_ssh_key.operator.id]
#   user_data = templatefile("${path.module}/../bootstrap/cloud-init.yaml", {
#     tailscale_auth_key = var.tailscale_auth_key
#     hostname           = var.vm_hostname
#   })
#
#   tags = ["joppa-primary", "dr-bootstrap"]
# }
#
# resource "digitalocean_ssh_key" "operator" {
#   name       = "wallypad-2026-04-29"
#   public_key = file("~/.ssh/id_ed25519.pub")
# }
#
# output "joppa_ip" {
#   value = digitalocean_droplet.joppa.ipv4_address
# }

# Hetzner Cloud — primary failover target (current standing host: hetz-1)
#
# TODO: requires HCLOUD_TOKEN env var (or hcloud_token variable). Token created
#       at https://console.hetzner.cloud/projects/<id>/security/tokens
#
# When live, this provisions a CPX31 (4 vCPU / 8 GB / 160 GB / €14/mo) in hel1.

# terraform {
#   required_providers {
#     hcloud = {
#       source  = "hetznercloud/hcloud"
#       version = "~> 1.45"
#     }
#   }
# }
#
# provider "hcloud" {
#   # token from HCLOUD_TOKEN env var
# }
#
# resource "hcloud_server" "joppa" {
#   name        = var.vm_hostname
#   image       = "ubuntu-24.04"
#   server_type = "cpx31"
#   location    = "hel1"
#   ssh_keys    = [hcloud_ssh_key.operator.id]
#   user_data   = templatefile("${path.module}/../bootstrap/cloud-init.yaml", {
#     tailscale_auth_key = var.tailscale_auth_key
#     hostname           = var.vm_hostname
#   })
#
#   labels = {
#     role    = "joppa-primary"
#     managed = "dr-bootstrap"
#   }
# }
#
# resource "hcloud_ssh_key" "operator" {
#   name       = "wallypad-2026-04-29"
#   public_key = file("~/.ssh/id_ed25519.pub")
# }
#
# output "joppa_ip" {
#   value = hcloud_server.joppa.ipv4_address
# }

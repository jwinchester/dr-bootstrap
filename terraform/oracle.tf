# Oracle Cloud — secondary backup failover target (cold, free-tier-compatible)
#
# TODO: requires Oracle Cloud auth (OCI CLI config or env vars):
#       TF_VAR_tenancy_ocid, TF_VAR_user_ocid, TF_VAR_fingerprint,
#       TF_VAR_private_key_path, TF_VAR_region, TF_VAR_compartment_ocid.
#       Region availability for A1.Flex shapes is finicky — falling back to
#       Standard-4GB-equivalent (VM.Standard.E2.1.Micro) if A1 unavailable.
#
# Notes:
# - Oracle's "Always Free" A1.Flex tier (4 OCPU / 24 GB) is hardware-rationed;
#   v1.x DR design tried "region roulette" to find available capacity.
#   v2.0 design treats Oracle as cold backup, not primary.
# - PAYG account required to bypass region availability; standing cost ~$0
#   when stopped, ~$0.048/hr when running.

# terraform {
#   required_providers {
#     oci = {
#       source  = "oracle/oci"
#       version = "~> 5.0"
#     }
#   }
# }
#
# provider "oci" {
#   tenancy_ocid     = var.tenancy_ocid
#   user_ocid        = var.user_ocid
#   fingerprint      = var.fingerprint
#   private_key_path = var.private_key_path
#   region           = var.region
# }
#
# resource "oci_core_instance" "joppa" {
#   compartment_id      = var.compartment_ocid
#   availability_domain = data.oci_identity_availability_domain.ad.name
#   shape               = "VM.Standard.A1.Flex"
#
#   shape_config {
#     ocpus         = 2
#     memory_in_gbs = 12
#   }
#
#   create_vnic_details {
#     subnet_id        = var.subnet_id
#     assign_public_ip = true
#   }
#
#   source_details {
#     source_type = "image"
#     source_id   = var.ubuntu_2404_arm_ocid  # region-specific
#   }
#
#   metadata = {
#     ssh_authorized_keys = file("~/.ssh/id_ed25519.pub")
#     user_data           = base64encode(templatefile(
#       "${path.module}/../bootstrap/cloud-init.yaml",
#       {
#         tailscale_auth_key = var.tailscale_auth_key
#         hostname           = var.vm_hostname
#       }
#     ))
#   }
#
#   display_name = var.vm_hostname
#   freeform_tags = {
#     role    = "joppa-primary"
#     managed = "dr-bootstrap"
#   }
# }

variable "vendor" {
  description = "Failover target: hetzner | do | oracle"
  type        = string
  default     = ""
}

variable "tailscale_auth_key" {
  description = "Pre-minted Tailscale auth key for new VM to join tailnet"
  type        = string
  sensitive   = true
  default     = "" # empty default lets `terraform destroy` work without re-supplying
}

variable "age_public_key" {
  description = "age public key for encrypting any new secrets generated post-failover"
  type        = string
  default     = "age17n0a09dp2ddyeqxqdp6z8szlyplfmmnyu6ep9dqerr0370y4katsrnzvh2"
}

variable "b2_account_id" {
  description = "Backblaze B2 application key ID for restic restore (read-only key)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "b2_account_key" {
  description = "Backblaze B2 application key for restic restore"
  type        = string
  sensitive   = true
  default     = ""
}

variable "vm_hostname" {
  description = "Hostname for the new primary (e.g. hetz-2, do-1, orac-1). REQUIRED."
  type        = string
}

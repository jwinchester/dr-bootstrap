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

# --- B2 tarball fetch (privatized dr-bootstrap path) ---
# Cloud-init pulls dr-bootstrap-YYYY-MM-DD.tar.gz from b2://uluhe-secrets/
# instead of `git clone` from GitHub, so the failover path doesn't assume
# GitHub is reachable. The wrapper mints a short-lived
# b2_get_download_authorization token (prefix-scoped to "dr-bootstrap-") and
# passes it through these variables. Keep them empty for the legacy git-clone
# path; cloud-init falls back to git clone when b2_auth_token is "".

variable "b2_download_url" {
  description = "B2 download URL base (from b2_authorize_account.apiInfo.storageApi.downloadUrl)"
  type        = string
  default     = ""
}

variable "b2_auth_token" {
  description = "Short-lived prefix-scoped B2 download token (from b2_get_download_authorization)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "tarball_name" {
  description = "Tarball file name in uluhe-secrets bucket (e.g. dr-bootstrap-2026-04-30.tar.gz)"
  type        = string
  default     = ""
}

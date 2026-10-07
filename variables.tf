# Change History:
# 2026-10-07 Steve Hager v2.0 Adding subfolders under environment folders.
# 2026-10-07 Steve Hager v2.1 Adding subfolders under domains subfolders.
# 2026-10-07 Steve Hager v2.2 Adding top level folders (expected to be used for common and bootstrap projects).
# 2026-10-07 Steve Hager v2.2.1 Shorted the default names in environments to avoid an name-too-long error.

variable "org_id" {
  description = "Numeric organization ID (gcloud organizations list, ID column)."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.org_id))
    error_message = "Use the numeric organization ID, not the directory customer ID."
  }
}

variable "terraform_service_account" {
  description = "Email of the Terraform service account created by the bootstrap."
  type        = string
}

variable "folder_prefix" {
  description = "Prefix for folder display names."
  type        = string
  default     = "fldr"
}

variable "environments" {
  description = "Top-level folders to create under the organization, one per environment."
  type        = list(string)
  default     = ["lab", "dev", "test", "prod"]

  validation {
    condition     = alltrue([for e in var.environments : can(regex("^[a-z][a-z0-9-]{1,20}$", e))])
    error_message = "Environment names must be lowercase letters, digits, or hyphens, starting with a letter."
  }
}

variable "folder_iam" {
  description = <<-EOT
    Optional IAM grants on any managed folder. Keys are folder keys:
      shared folder:   common
      environment:     prod
      env/subfolder:   "prod/infrastructure"
      env/domain:      "prod/domains/customer"
    Example:
      {
        prod                    = [{ role = "roles/viewer", member = "group:org-admins@example.com" }]
        "dev/domains/customer"  = [{ role = "roles/editor", member = "group:customer-devs@example.com" }]
      }
  EOT
  type = map(list(object({
    role   = string
    member = string
  })))
  default = {}
}

variable "deletion_protection" {
  description = "Prevent Terraform from deleting folders. Set false deliberately to remove one."
  type        = bool
  default     = true
}

variable "env_subfolders" {
  description = "Subfolders to create inside every environment folder."
  type        = list(string)
  default     = ["infrastructure", "services", "domains"]

  validation {
    condition     = alltrue([for s in var.env_subfolders : can(regex("^[a-z][a-z0-9-]{1,20}$", s))])
    error_message = "Subfolder names: lowercase letters, digits, hyphens; start with a letter; 2-21 chars."
  }
}

variable "domains" {
  description = "Domain folders to create under each environment's domains subfolder."
  type        = list(string)
  default     = ["customer", "product", "location"]

  validation {
    condition     = alltrue([for d in var.domains : can(regex("^[a-z][a-z0-9-]{1,20}$", d))])
    error_message = "Domain names: lowercase letters, digits, hyphens; start with a letter; 2-21 chars."
  }
}

variable "shared_folders" {
  description = "Top-level folders outside the environment hierarchy (no subfolders)."
  type        = list(string)
  default     = ["bootstrap", "common"]

  validation {
    condition     = alltrue([for s in var.shared_folders : can(regex("^[a-z][a-z0-9-]{1,20}$", s))])
    error_message = "Shared folder names: lowercase letters, digits, hyphens; start with a letter; 2-21 chars."
  }
}

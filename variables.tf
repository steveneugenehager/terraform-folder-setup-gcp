# Change History:
# 2026-10-07 Steve Hager v2.0 Adding subfolders under environment folders.

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
  default     = ["lab", "development", "nonproduction", "production"]

  validation {
    condition     = alltrue([for e in var.environments : can(regex("^[a-z][a-z0-9-]{1,20}$", e))])
    error_message = "Environment names must be lowercase letters, digits, or hyphens, starting with a letter."
  }
}

variable "folder_iam" {
  description = <<-EOT
    Optional IAM grants on each folder, keyed by environment name. Example:
      {
        development = [{ role = "roles/viewer", member = "group:devs@example.com" }]
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

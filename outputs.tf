# Change History:
# 2026-10-07 Steve Hager v2.0 Adding subfolders under environment folders.
# 2026-10-07 Steve Hager v2.1 Adding subfolders under domains subfolders.
# 2026-10-07 Steve Hager v2.2 Adding top level folders (expected to be used for common and bootstrap projects).

output "shared_folder_ids" {
  description = "Shared top-level folder IDs keyed by name (e.g. \"common\")."
  value       = { for k, f in google_folder.shared : k => f.name }
}

output "folder_ids" {
  description = "Folder resource names (folders/NNN) by environment, for use as folder_id elsewhere."
  value       = { for env, f in google_folder.env : env => f.name }
}

output "folder_display_names" {
  description = "Folder display names by environment."
  value       = { for env, f in google_folder.env : env => f.display_name }
}

output "subfolder_ids" {
  description = "Subfolder IDs keyed \"<env>/<subfolder>\"."
  value       = { for key, f in google_folder.env_sub : key => f.name }
}

output "domain_folder_display_names" {
  description = "Domain folder display names keyed by \"<env>/domains/<domain>\"."
  value       = { for key, f in google_folder.domain : key => f.display_name }
}

output "domain_folder_ids" {
  description = "Domain folder IDs keyed \"<env>/domains/<domain>\"."
  value       = { for key, f in google_folder.domain : key => f.name }
}

# Change History:
# 2026-10-07 Steve Hager v2.0 Adding subfolders under environment folders.

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

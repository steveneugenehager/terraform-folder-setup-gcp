output "folder_ids" {
  description = "Folder resource names (folders/NNN) by environment, for use as folder_id elsewhere."
  value       = { for env, f in google_folder.env : env => f.name }
}

output "folder_display_names" {
  description = "Folder display names by environment."
  value       = { for env, f in google_folder.env : env => f.display_name }
}

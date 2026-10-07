# ---------------------------------------------------------------------------
# Environment folders directly under the organization.
# ---------------------------------------------------------------------------
# Change History:
# 2026-10-07 Steve Hager v2.0 Adding subfolders under environment folders.
# 2026-10-07 Steve Hager v2.1 Adding subfolders under domains subfolders.
# 2026-10-07 Steve Hager v2.2 Adding top level folders (expected to be used for common and bootstrap projects).
# 2026-10-07 Steve Hager v2.2.1 Fixed a couple of bugs related to length of folder names. 
#                                  In two places the folder_prefix wasn't being accounted for in the checks.
# 2026-10-07 Steve Hager v2.2.2 Corrected an error message related to folder_iam condition.

# ---------------------------------------------------------------------------
# Shared top-level folders: org-wide services that belong to no environment.
# ---------------------------------------------------------------------------
resource "google_folder" "shared" {
  for_each = toset(var.shared_folders)

  display_name        = "${var.folder_prefix}-${each.key}"
  parent              = "organizations/${var.org_id}"
  deletion_protection = var.deletion_protection

  lifecycle {
# The precondition matters because of a later merge. If "common" were also an environment name, one key would silently overwrite the other.
    precondition {
      condition     = !contains(var.environments, each.key)
      error_message = "'${each.key}' is in both shared_folders and environments; folder keys must be unique."
    }
  }
}

# ---------------------------------------------------------------------------
# Top-level folders for each environment.
# ---------------------------------------------------------------------------
resource "google_folder" "env" {
  for_each = toset(var.environments)

  display_name        = "${var.folder_prefix}-${each.key}"
  parent              = "organizations/${var.org_id}"
  deletion_protection = var.deletion_protection
}

# ---------------------------------------------------------------------------
# Optional folder-level IAM. Grants made here apply to every project
# placed in the folder, now and in the future.
# ---------------------------------------------------------------------------

locals {
  # Flatten { env = [ {role, member}, ... ] } into one map entry per grant,
  # keyed so each grant has a stable identity in state.
  folder_iam_bindings = {
    for b in flatten([
      for env, grants in var.folder_iam : [
        for g in grants : {
          env    = env
          role   = g.role
          member = g.member
        }
      ]
    ]) : "${b.env}|${b.role}|${b.member}" => b
  }
}

resource "google_folder_iam_member" "grants" {
  for_each = local.folder_iam_bindings

  folder = lookup(local.all_folder_ids, each.value.env, null)
  role   = each.value.role
  member = each.value.member

  lifecycle {
    precondition {
      condition     = contains(keys(local.all_folder_ids), each.value.env)
      error_message = "folder_iam key '${each.value.env}' doesn't match a managed folder. Use a shared folder (common), an environment (prod), env/subfolder (prod/infrastructure), or env/domains/domain (prod/domains/customer)."
    }
  }
}

locals {
  # "production/infrastructure" => { env = "production", sub = "infrastructure" }
  env_subfolder_pairs = {
    for p in setproduct(var.environments, var.env_subfolders) :
    "${p[0]}/${p[1]}" => { env = p[0], sub = p[1] }
  }

  # Every folder this config manages, so IAM grants can target either level.
  all_folder_ids = merge(
    { for k, f in google_folder.shared : k => f.name },
    { for env, f in google_folder.env : env => f.name },
    { for key, f in google_folder.env_sub : key => f.name },
    { for key, f in google_folder.domain : key => f.name },
  )
}

resource "google_folder" "env_sub" {
  for_each = local.env_subfolder_pairs

  display_name        = "${var.folder_prefix}-${each.value.env}-${each.value.sub}"
  parent              = google_folder.env[each.value.env].name
  deletion_protection = var.deletion_protection

  lifecycle {
    precondition {
      condition     = length("${var.folder_prefix}-${each.value.env}-${each.value.sub}") <= 30
      error_message = "Folder display name '${var.folder_prefix}-${each.value.env}-${each.value.sub}' exceeds GCP's 30-char limit."
    }
  }
}

locals {
  domains_subfolder = "domains"

  # "production/domains/customer" => { env = "production", domain = "customer" }
  # Empty if "domains" isn't in env_subfolders, so nothing is orphaned.
  domain_folder_pairs = {
    for p in setproduct(var.environments, var.domains) :
    "${p[0]}/${local.domains_subfolder}/${p[1]}" => { env = p[0], domain = p[1] }
    if contains(var.env_subfolders, local.domains_subfolder)
  }
}

resource "google_folder" "domain" {
  for_each = local.domain_folder_pairs

  display_name        = "${var.folder_prefix}-${each.value.env}-${each.value.domain}"
  parent              = google_folder.env_sub["${each.value.env}/${local.domains_subfolder}"].name
  deletion_protection = var.deletion_protection

  lifecycle {
    precondition {
      condition     = length("${var.folder_prefix}-${each.value.env}-${each.value.domain}") <= 30
      error_message = "Folder display name '${var.folder_prefix}-${each.value.env}-${each.value.domain}' exceeds GCP's 30-char limit."
    }
  }
}

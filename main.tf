# ---------------------------------------------------------------------------
# Environment folders directly under the organization.
# ---------------------------------------------------------------------------
# Change History:
# 2026-10-07 Steve Hager v2.0 Adding subfolders under environment folders.

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
      error_message = "folder_iam key '${each.value.env}' is not in var.environments."
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
    { for env, f in google_folder.env : env => f.name },
    { for key, f in google_folder.env_sub : key => f.name },
  )
}

resource "google_folder" "env_sub" {
  for_each = local.env_subfolder_pairs

  display_name        = "${each.value.env}-${each.value.sub}"
  parent              = google_folder.env[each.value.env].name
  deletion_protection = var.deletion_protection

  lifecycle {
    precondition {
      condition     = length("${each.value.env}-${each.value.sub}") <= 30
      error_message = "Folder display name '${each.value.env}-${each.value.sub}' exceeds GCP's 30-char limit."
    }
  }
}

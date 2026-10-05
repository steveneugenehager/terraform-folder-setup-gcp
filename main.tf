# ---------------------------------------------------------------------------
# Environment folders directly under the organization.
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

  folder = google_folder.env[each.value.env].name
  role   = each.value.role
  member = each.value.member

  lifecycle {
    precondition {
      condition     = contains(var.environments, each.value.env)
      error_message = "folder_iam key '${each.value.env}' is not in var.environments."
    }
  }
}

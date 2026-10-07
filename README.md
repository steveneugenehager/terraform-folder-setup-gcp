# GCP Organization Folders

Creates the organization's folder hierarchy: shared top-level folders,
one folder per environment, standard subfolders inside every environment,
and domain folders inside each environment's `domains` subfolder. Optionally
grants IAM on any of those folders, and exports every folder ID for the
configurations that create projects inside them.

Runs entirely as the bootstrap Terraform service account (impersonation, no
keys). It depends on the bootstrap configuration for the state bucket and that
service account, which holds Folder Admin at the organization.

## What it creates

With the default variables:

```
Organization
├── fldr-bootstrap                      shared folders (no subfolders)
├── fldr-common
├── fldr-lab
│   ├── fldr-lab-infrastructure
│   ├── fldr-lab-services
│   └── fldr-lab-domains
│       ├── fldr-lab-customer
│       ├── fldr-lab-product
│       └── fldr-lab-location
├── fldr-<env>                          …same shape for every environment
│   ├── fldr-<env>-infrastructure
│   ├── fldr-<env>-services
│   └── fldr-<env>-domains
│       └── fldr-<env>-<domain>
```

| Level | Variable | Display name | Key (for outputs and `folder_iam`) |
|---|---|---|---|
| Shared | `shared_folders` | `<prefix>-<name>` | `common` |
| Environment | `environments` | `<prefix>-<env>` | `production` |
| Subfolder | `env_subfolders` | `<prefix>-<env>-<sub>` | `production/infrastructure` |
| Domain | `domains` | `<prefix>-<env>-<domain>` | `production/domains/customer` |

What each level is for:

- **Shared** folders hold org-wide services that belong to no environment.
  `bootstrap` holds the seed project (Terraform state and service accounts);
  keep its IAM minimal. `common` holds things like the IAM ops project,
  central logging and the billing export.
- **infrastructure** holds per-environment shared plumbing: Shared VPC host
  projects, DNS and logging sinks.
- **services** holds shared platform services for the environment.
- **domains** holds one folder per business or data domain, so each domain
  team can be granted access to its own subtree only.

Domain folders are created only when `domains` is one of the `env_subfolders`.

### Naming limit

GCP folder display names are limited to **30 characters**, and the limit
applies to the full name, prefix included. `fldr-development-infrastructure`
is 31 characters and will fail. Keep environment names short (`dev`, `stg`,
`prd`), or shorten or empty `folder_prefix`.

## Prerequisites

- The bootstrap stage has been applied.
- Your Google account is in the bootstrap's `terraform_admins`, which grants
  Token Creator on the Terraform service account.
- `gcloud` and Terraform are installed (see the bootstrap repo's `setup.sh`).

## Authentication

Terraform authenticates as **you**, then impersonates the Terraform service
account for every call: both the provider and the GCS backend.

```bash
gcloud auth login
gcloud auth application-default login            # add --no-browser on a headless VM
gcloud auth application-default set-quota-project <seed-project-id>

# Verify the impersonation chain before involving Terraform:
gcloud auth print-access-token \
  --impersonate-service-account=<terraform-sa-email> >/dev/null && echo "impersonation OK"
```

`<seed-project-id>` and `<terraform-sa-email>` are bootstrap outputs
(`seed_project_id`, `terraform_service_account`).

## Setup

```bash
cp backend.hcl.example backend.hcl            # bucket + SA from bootstrap outputs
cp terraform.tfvars.example terraform.tfvars  # org ID + SA, plus any overrides
```

Both files are git-ignored.

## Run

```bash
terraform init -backend-config=backend.hcl
terraform fmt && terraform validate
terraform plan -out=folders.plan
terraform apply folders.plan
```

State is stored at `gs://<seed-project-id>-tfstate/org/folders/`.

Terraform creates parents before children automatically, because each
subfolder references its parent's ID. Siblings are created in parallel.
Destroys run in reverse order.

## Variables

| Name | Default | Purpose |
|---|---|---|
| `org_id` | *required* | Numeric organization ID (`gcloud organizations list`). |
| `terraform_service_account` | *required* | Bootstrap Terraform SA to impersonate. |
| `folder_prefix` | `"fldr"` | Prefix on every folder's display name. |
| `shared_folders` | `["bootstrap", "common"]` | Top-level folders outside the environment hierarchy. |
| `environments` | `["lab", "development", "nonproduction", "production"]` | One top-level folder each. |
| `env_subfolders` | `["infrastructure", "services", "domains"]` | Created inside every environment. |
| `domains` | `["customer", "product", "location"]` | Created inside every `<env>/domains`. |
| `folder_iam` | `{}` | Optional grants; see below. |
| `deletion_protection` | `true` | Blocks Terraform from deleting folders. |

A name may not appear in both `shared_folders` and `environments`; a
precondition stops the plan if it does.

## Folder IAM

Grants inherit downward to every folder and project below the target, now and
in the future. Key `folder_iam` by any folder's key from the table above. Grant
to groups, not individuals. Keys containing `/` must be quoted.

```hcl
folder_iam = {
  production = [
    { role = "roles/viewer", member = "group:gcp-organization-admins@yourdomain.com" },
  ]
  "development/domains/customer" = [
    { role = "roles/editor", member = "group:customer-domain-devs@yourdomain.com" },
  ]
}
```

## Outputs

| Output | Keyed by | Example key |
|---|---|---|
| `shared_folder_ids` | shared folder name | `common` |
| `folder_ids` | environment | `production` |
| `folder_display_names` | environment | `production` |
| `subfolder_ids` | `<env>/<subfolder>` | `production/infrastructure` |
| `domain_folder_ids` | `<env>/domains/<domain>` | `production/domains/customer` |
| `domain_folder_display_names` | `<env>/domains/<domain>` | `production/domains/customer` |

IDs are in the `folders/NNN` form, ready to use as `folder_id`.

## Using the folder IDs elsewhere

```hcl
data "terraform_remote_state" "folders" {
  backend = "gcs"
  config = {
    bucket                      = "<seed-project-id>-tfstate"
    prefix                      = "org/folders"
    impersonate_service_account = "<terraform-sa-email>"
  }
}

locals {
  folders = data.terraform_remote_state.folders.outputs
}

resource "google_project" "iam_ops" {
  # ...
  folder_id = local.folders.shared_folder_ids["common"]
}

resource "google_project" "prod_net_host" {
  # ...
  folder_id = local.folders.subfolder_ids["production/infrastructure"]
}
```

## Changing the hierarchy

**Adding** a shared folder, environment, subfolder or domain: add the name to
its list and apply. Adding an environment creates its whole subtree.

**Renaming** changes the key, so Terraform plans a destroy and a create.
Rename in place instead with a `moved` block, which turns it into an
in-place display-name update:

```hcl
moved {
  from = google_folder.env["development"]
  to   = google_folder.env["dev"]
}
```

Every subfolder and domain under a renamed environment needs a `moved` block
too, because their keys include the environment name.

**Removing** a folder:

1. Move or delete every project and folder in it. GCP won't delete a
   non-empty folder.
2. Set `deletion_protection = false` and apply.
3. Remove the name and apply.
4. Set `deletion_protection = true` again.

Deleted folders can be restored for about 30 days.

**Moving an existing project into a folder**, for example the seed project
into `fldr-bootstrap`, is done once as an org admin:

```bash
gcloud beta projects move <project-id> --folder=<folder-number>
```

Then set `folder_id` in that project's own Terraform so it agrees. Moving a
project changes the org policies and folder IAM it inherits, so set the
folder's grants first.

## Adopting folders created in the console

Import an existing folder instead of creating a duplicate:

```hcl
import {
  to = google_folder.env["development"]
  id = "folders/123456789"
}

import {
  to = google_folder.env_sub["development/infrastructure"]
  id = "folders/234567890"
}
```

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `Backend initialization required` | No `.terraform/` in this checkout. Run `terraform init -backend-config=backend.hcl`. |
| `Error acquiring the state lock` | An interrupted run left a lock. Confirm nothing is running, then `terraform force-unlock <ID>`. |
| `getAccessToken` permission denied | You aren't in `terraform_admins`, or the grant is still propagating. |
| Display name invalid or too long | Full name over 30 characters; see [Naming limit](#naming-limit). |
| `Cannot delete folder` / folder not empty | It still contains projects or folders. |
| Plan shows folders being destroyed and recreated | A name changed; use a `moved` block. |

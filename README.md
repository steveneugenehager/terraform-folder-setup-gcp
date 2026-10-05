# GCP Organization Folders

Creates the top-level environment folders under the organization:

```
Organization
├── fldr-development
├── fldr-nonproduction
└── fldr-production
```

Optionally grants IAM roles on each folder. Folder IDs are exported for the
configurations that create projects inside them.

Depends on the bootstrap configuration, which provides the state bucket and the
Terraform service account (with Folder Admin at the organization).

## Setup

```bash
cp backend.hcl.example backend.hcl            # bucket and service account from bootstrap outputs
cp terraform.tfvars.example terraform.tfvars  # org ID and service account
```

Your own account needs permission to impersonate the Terraform service account
(the bootstrap grants this to everyone in `terraform_admins`).

## Run

```bash
terraform init -backend-config=backend.hcl
terraform fmt && terraform validate
terraform plan -out=folders.plan
terraform apply folders.plan
```

State is stored at `gs://SEED_PROJECT_ID-tfstate/org/folders/`.

## Using the folder IDs elsewhere

```hcl
data "terraform_remote_state" "folders" {
  backend = "gcs"
  config = {
    bucket                      = "SEED_PROJECT_ID-tfstate"
    prefix                      = "org/folders"
    impersonate_service_account = "terraform@SEED_PROJECT_ID.iam.gserviceaccount.com"
  }
}

resource "google_project" "dev_net_host" {
  # ...
  folder_id = data.terraform_remote_state.folders.outputs.folder_ids["development"]
}
```

## Adding or removing folders

Add a name to `environments` and apply. To remove one, first move or delete
every project in it (non-empty folders can't be deleted), then set
`deletion_protection = false`, apply, remove the name, and apply again.
Deleted folders can be restored for about 30 days.

## Adopting folders created in the console

If a folder already exists, import it instead of creating a duplicate:

```hcl
import {
  to = google_folder.env["development"]
  id = "folders/123456789"
}
```

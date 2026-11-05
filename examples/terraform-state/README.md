# Terraform State in GitLab

Every job runs in a fresh VM that gets thrown away, so a job can't keep Terraform state on its own disk.  This example keeps the state in GitLab, which also locks it while a job is using it and encrypts it at rest.

Copy `main.tf` and `.gitlab-ci.yml` to the root of a GitLab project and commit them.  The first pipeline creates the resource.  Run the pipeline again, and Terraform reports `No changes`, even though it's in a brand-new VM, because the state came from GitLab.

`CI_JOB_TOKEN` is the job's own token, so there's no secret for you to store.  The person running the pipeline needs the Maintainer or Owner role, because `terraform apply` locks the state.  You can see the state under **Operate --> Terraform states**.

Already have state in a local file?  Add the `backend "http"` block, set the same `TF_HTTP_` variables, and run `terraform init -migrate-state` to move it into GitLab.

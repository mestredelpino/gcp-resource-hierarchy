# Google Cloud resource hierarchy with Terraform
The repository containing the scripts and terraform code to create a GCP landing zone

1. Log in to Google Cloud with your admin account
2. Create a base project:

```
gcloud projects create base-project01
```

Create a bucket in which we will store our bootstrap terraform states:

For [location](https://cloud.google.com/storage/docs/locations) choose either a multi-region (EU, US, ASIA), dual-region (NAM4, ASIA1, EU4), or single-region.

```
gcloud storage buckets create gs://<BUCKET_NAME> \
--location <BUCKET_LOCATION> 
```

### Create a bootstrap service account

Although we could just run the Terraform CLI and create the resource hierarchy from our console, it is most than likely
that this is only the first step to build a Landing Zone, I start

Create service account to perform your automated bootstrap actions.
```
gcloud iam service-accounts create bootstrap \
--description="bootstrap" \
--display-name="bootstrap" \
--project=base-project01
```

1.Get the Organization ID
```
org_id=$(gcloud organizations list | awk 'NR==2 {print $2}')
```

There are four roles you will need:
- Organization viewer
- Folder admin
- Project creator
- Project deleter (optional)

Add IAM policy bindings to the bootstrap service account:
```
gcloud organizations add-iam-policy-binding $org_id \
--member=serviceAccount:bootstrap@base-project01.iam.gserviceaccount.com \
--role="roles/resourcemanager.organizationViewer"

gcloud organizations add-iam-policy-binding $org_id \
--member=serviceAccount:bootstrap@base-project01.iam.gserviceaccount.com \
--role="roles/resourcemanager.folderAdmin"

gcloud organizations add-iam-policy-binding $org_id \
--member=serviceAccount:bootstrap@base-project01.iam.gserviceaccount.com \
--role="roles/resourcemanager.projectCreator"

gcloud organizations add-iam-policy-binding $org_id \
--member=serviceAccount:bootstrap@base-project01.iam.gserviceaccount.com \
--role="roles/resourcemanager.projectDeleter"
```

Add also the "storage object admin" a project level to store terraform state on a bucket.

```
gcloud projects add-iam-policy-binding base-project01 \
--member=serviceAccount:bootstrap@base-project01.iam.gserviceaccount.com \
--role="roles/storage.objectAdmin"
```


### Resource Hierarchy

Create a file "terraform.tfvars" and store it in the bucket you created earlier

You do not need to create every tier of folders, and you can create projects under any folder.
```
org_domain = "yourdomain.com"
resource_hierarchy = [
  {
    department  = "Department A"
    projects    = ["department-a-dev05","department-a-prod05"]
  },
  {
    department  = "Shared Projects",
    projects    = ["Monitoring"]
    teams =[{
      name = "Team X"
      projects    = ["team-x-dev01","team-x-prod01"]

    }]
  },
  {
    department  = "Department B",
    teams     = [
      {
        name = "Team Y"
      },
      {
        name = "Team Z"
        products = [{
          name = "Product 1"
          projects = ["product-1-dev01","product-1-test01","product-1-prod01"]
        },
          {
            name = "Product 2"
          }]
      }
    ]
  }
]
```

Upload your terraform.tfvars to the bucket:
```
gcloud storage cp ./terraform.tfvars gs://bootstrap1234/terraform/resource_hierarchy/terraform.tfvars
```

Create also your backend.tf file, to store your Terraform state in the bucket.
```
terraform {
  backend "gcs" {
    bucket  = "<YOUR_BUCKET_NAME>"
    prefix  = "terraform/resource_hierarchy"
  }
}
```
Then push it to the bucket
```
gcloud storage cp ./backend.tf gs://bootstrap1234/terraform/resource_hierarchy/backend.tf
```
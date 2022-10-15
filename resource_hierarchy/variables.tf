variable "org_domain" {
  type = string
  description = "The domain corresponding to your organization (e.g. domain.com)"
}

variable "resource_hierarchy" {
  type = any
  description = "The desired resource hierarchy of folders and projects to create."
}



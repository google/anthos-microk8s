# variables.tf - declare Terraform variables

variable project {
  description        = "Project ID to use."
  type               = string
}

variable SAName  {
  description        = "SA for Anthos registration."
  type               = string
}

variable suffix  {
  description        = "Suffix for resource names."
  type               = string
}

# variables.tf - declare Terraform variables

# May of the values of the variables are defined in the main terraform.tfvars
# file in the root module.  All of them are passed to the module as input
# variables.

variable CMprivateKey {
  description        = "Anthos Configuration Management private key."
  type               = string
}

variable cmRepoName {
  description        = "Anthos Configuration Management repository name."
  type               = string
}

variable initCompletedLabel {
  description        = "Label key to apply after cloud-init has completed."
  type               = string
}

variable instanceInfo {
  description        = "Map of instances as in top level terraform.tfvars."
  type               = map
}

variable gitBranch {
  description        = "Branch to use for git commits"
  type               = string
}

variable microk8sRelease {
  description        = "The microk8s release."
  type               = string
}

variable project {
  description        = "Google Cloud project id."
  type               = string
}

variable SAemail  {
  description        = "Service Account email."
  type               = string
}

variable SAprivateKey  {
  description        = "Service Account private key."
  type               = string
}

variable suffix  {
  description        = "Suffix for resource names."
  type               = string
}

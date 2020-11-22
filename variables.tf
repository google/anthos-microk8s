# variables.tf - declare all Terraform variables
#
# See terraform.tfvars for more detailed information on the meanings
# of the variables.

variable anthosConfigReleasePath {
  description        = "Location for Anthos Config components like nomos"
  type               = string
}

variable anthosRegisterSA  {
  description        = "SA for Anthos registration."
  type               = string
}

variable defaultRegion  {
  description        = "Default region to use."
  type               = string
}

variable gitBranch {
  description        = "branch to use for git commits"
  type               = string
}

variable initCompletedLabel {
  description        = "Label key to apply after cloud-init has completed."
  type               = string
}

variable instanceInfo {
  description        = "Map of microk8s instances to create."
  type               = map
}

variable microk8sRelease {
  description        = "The microk8s release."
  type               = string
}

variable project {
  description        = "Project ID to use."
  type               = string
}

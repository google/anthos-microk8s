# terraform.tfvars - define values for this project

# project  - string - The Google Cloud project ID in which to deploy
#   the resources
#
# DEFINE THIS WITH terraform apply -var="project=MY_PROJECT_ID"

# defaultRegion - string - The default Google Cloud region in which to
#   deploy resources

defaultRegion           = "us-central1"

# Service accounts
#
# anthosRegisterSA - string - the name of the service account to create to
#   register microk8s clusters.  The random suffix will be added to this.

anthosRegisterSA        = "anthos-register"

# Git information
#
# gitBranch - string - the branch to use synchronize

gitBranch               = "microk8s"

# Instance information

# initCompletedLabel - string - label key to apply to intances at the
#   conclusion of cloud-init provisioning.  The label value will be set
#   to the random suffix used during this build.

initCompletedLabel      = "cloud-init-done"

# microk8sRelease - string - The micok8s release channel.
# The goal is to use similar versions for Anthos, kubectl, and microk8s.

microk8sRelease         = "1.17/stable"

# anthosConfigReleasePath - string - The release path for components such
# as the config operator and nomos.

anthosConfigReleasePath = "gs://config-management-release/released/latest"

# instanceInfo - map - Information for the microk8s instances to launch.
#   Here is an example of the format of this map:
#
# instanceInfo = {
#   microk8s-us-central1-b = {
#     name          = "microk8s-us-central1-b"
#     network       = "microk8s-network"
#     zone          = "us-central1-b"
#     machineType   = "e2-small"
#     imageProject  = "ubuntu-os-cloud"
#     imageFamily   = "ubuntu-2004-lts"
#     instanceCount = 1
#   },
#   ...
#   ...
# }
#
# Field definitions:
#
# msp key       - string - for clarity this should match the name field
# name          - string - the name of the instance
# network       - string - the **existing** network with **automatic subnets**
# zone          - string - the zone in which to deploy the instances
# machineType   - string - the machineType of the instances
# imageProject  - string - the project containing the images for the instances
# imageFamily   - string - the family of the images for the instances
# instanceCount - number - the number of instances to spin up of this map entry


instanceInfo = {
  microk8s-us-central1-b = {
    name          = "microk8s-us-central1-b"
    network       = "microk8s-network"
    zone          = "us-central1-b"
    machineType   = "e2-small"
    imageProject  = "ubuntu-os-cloud"
    imageFamily   = "ubuntu-2004-lts"
    instanceCount = 1
  }
}

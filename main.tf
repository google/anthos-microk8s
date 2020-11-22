# main.tf - entry point for the Terraform project.

# Define and configure providers.
#
# provider google - The Google Cloud provider
#
# provider random - Generates random suffixes for resource names.
# All resources are created with the same suffix for easier identification.
#
# provider null - For creating null resources not provided by Google Cloud.
# One such resource is used in the microk8s module for waiting for cloud-init
# to complete.

terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = ">= 3.42.0"
    }

    local = {
      source = "hashicorp/local"
      version = "~> 2.0.0"
    }

    null = {
      source = "hashicorp/null"
      version = "~> 3.0.0"
    }

    random = {
      source = "hashicorp/random"
      version = "~> 3.0.0"
    }

    tls = {
      source = "hashicorp/tls"
      version = "~> 3.0.0"
    }
  }
}

provider "google" {
  project = var.project
  region  = var.defaultRegion
}

# Generate a random suffix for Google Cloud resources. This is useful when
# tearing down and building the environment again. Using the same name can
# cause duplication errors due to the eventual consistency matters associated
# with IAM clean up. Special and uppercase characters are not used because
# they are not supported in certain Google Cloud resouirces.

resource "random_string" "randomSuffix" {
  length  = 6
  upper   = false
  lower   = true
  number  = true
  special = false
}

# Create the Google Cloud Service Account that will be used to register
# the cluster to the Anthos/GKE hub.

module "service_account" {
  source  = "./modules/serviceaccount"

  project = var.project
  SAName  = var.anthosRegisterSA
  suffix  = random_string.randomSuffix.result
}

# Generate a public/private key pair for setting up Anthos Config Mgmt.
#
# The public key will be stored in the Anthos Configuration Management
# git repository that is provided by Cloud Source Repositories.
#
# The private key will be distributed to each microk8s cluster so it can
# pull the configuration from the git repository provided by Cloud Source
# Repositories.

resource "tls_private_key" "cmRepoKey" {
  algorithm   = "RSA"
  rsa_bits = 4096
}

# Create the repository on Cloud Source Repositories for the
# Anthos Configuration Management part of this exercise.

resource "google_sourcerepo_repository" "anthosConfigRepo" {
  name = "microk8-anthos-config-${random_string.randomSuffix.result}"
}

# Create the microk8s instances
#
# The Configuration Management repository private key (cmRepoKey) is encoded
# with base64 to make it easier to process in the microk8s module with
# cloud-init.

module "microk8s" {
  source             = "./modules/microk8s"

  initCompletedLabel = var.initCompletedLabel
  instanceInfo       = var.instanceInfo
  microk8sRelease    = var.microk8sRelease
  project            = var.project
  SAemail            = module.service_account.serviceAccountInfo.email
  SAprivateKey       = module.service_account.serviceAccountKeyInfo.private_key
  CMprivateKey       = base64encode(tls_private_key.cmRepoKey.private_key_pem)
  suffix             = random_string.randomSuffix.result
  cmRepoName         = google_sourcerepo_repository.anthosConfigRepo.name
  gitBranch          = var.gitBranch
}

resource "local_file" "cmPublicKeyOpsenSsh" {
    content     = tls_private_key.cmRepoKey.public_key_openssh
    filename = "${path.module}/anthos-cm/var/acm-public-key.openssh"
    file_permission = "0600"
    directory_permission = "0700"
}

resource "local_file" "setupRepo" {
    content = <<EOF
#!/bin/sh

# setup-repo
#
# Clone the Anthos Configuration Management repo.
#
# Initialize the repo using nomos.
#
# Create a new branch named microk8s.  The branch name must match with that
# specified in the config-management.yaml file on the cluster.
#
# Commit the new branch.

echo "Cloning repo..."
gcloud source repos clone \
  ${google_sourcerepo_repository.anthosConfigRepo.name} \
  --project=${var.project}

echo "Initializing repo with nomos..."
cd ${google_sourcerepo_repository.anthosConfigRepo.name}
nomos init --path .

echo "Performing first commit to microk8s branch..."
git config --local user.name "microk8s admin"
git config --local user.email "microk8s@example.com"
git checkout --orphan ${var.gitBranch}
git add .
git commit -m "initial commit"
git push -u origin ${var.gitBranch}

EOF
    filename = "${path.module}/anthos-cm/var/200-setup-repo"
    file_permission = "0700"
    directory_permission = "0700"
}

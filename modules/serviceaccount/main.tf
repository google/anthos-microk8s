# serviceaccount.tf
#
# Create the service account used for registrering the microk8s instances
# to the Anthos/GKE Hub. These roles are listed in the Anthos/GKE
# documentation.  The Compute Admin role is used because it allows for the
# management of public IP addresses and the ability to set labels on the
# GKE instances.  Labels will indicate whether the instance has completed its
# initialization with cloud-init.

resource "google_service_account" "anthosRegSA" {
  account_id = "${var.SAName}-${var.suffix}"
  display_name = "${var.SAName}-${var.suffix}"
}

resource "google_project_iam_member" "iamGkeHubConnect" {
  role = "roles/gkehub.connect"
  member = "serviceAccount:${google_service_account.anthosRegSA.email}"
}

resource "google_project_iam_member" "iamGkeHubAdmin" {
  role = "roles/gkehub.admin"
  member = "serviceAccount:${google_service_account.anthosRegSA.email}"
}

resource "google_project_iam_member" "computeAdmin" {
  role = "roles/compute.admin"
  member = "serviceAccount:${google_service_account.anthosRegSA.email}"
}

resource "google_service_account_key" "anthosRegSAKey" {
  service_account_id = google_service_account.anthosRegSA.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}

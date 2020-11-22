# outputs.tf

# output values for calling module

output "serviceAccountInfo" {
  value = google_service_account.anthosRegSA
  description = "The created service account."
}

output "serviceAccountKeyInfo" {
  value = google_service_account_key.anthosRegSAKey
  description = "The created service account key."
}

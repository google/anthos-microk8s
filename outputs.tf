# outputs.tf

output "Output10_resource_suffix" {
  value = random_string.randomSuffix.result
  description = "Resource suffix"
}

output "Output20_repository_name" {
  value = google_sourcerepo_repository.anthosConfigRepo.name
  description = "Cloud Source Repository name"
}

output "Output30_service_account_email" {
  value = module.service_account.serviceAccountInfo.email
  description = "Microk8s instance service account"
}

output "Output40_instance_names" {
  value = module.microk8s.instance_names
  description = "Instance names"
}

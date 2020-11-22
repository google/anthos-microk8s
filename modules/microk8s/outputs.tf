# outputs.tf

output "instance_names" {
  value = [ for i in google_compute_instance.microk8s_instances : i.name ]
}

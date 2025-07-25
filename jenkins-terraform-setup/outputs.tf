output "jenkins_public_ip" {
  value       = module.jenkins.jenkins_public_ip
  description = "Static public IP address of Jenkins server"
}

output "jenkins_private_ip" {
  value       = module.jenkins.jenkins_private_ip
  description = "Private IP address of Jenkins server"
}

output "jenkins_instance_id" {
  value       = module.jenkins.jenkins_instance_id
  description = "Instance ID of Jenkins server"
}
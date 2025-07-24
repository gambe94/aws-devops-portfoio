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

output "jenkins_agent_1_public_ip" {
  value       = module.jenkins.jenkins_agent_1_public_ip
  description = "Public IP of Jenkins Salesforce Agent"
}

output "jenkins_agent_1_private_ip" {
  value       = module.jenkins.jenkins_agent_1_private_ip
  description = "Private IP of Jenkins Salesforce Agent"
}

output "vpc_id" {
  value       = module.network.vpc_id
  description = "VPC ID where Jenkins infrastructure is deployed"
}
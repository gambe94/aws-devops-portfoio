provider "aws" {
  region = var.aws_region
}

module "network" {
  source = "./network"
}

module "jenkins" {
  source = "./jenkins"

  vpc_id                       = module.network.vpc_id
  subnet_id                    = module.network.public_subnet_id
  jenkins_ami_id               = var.jenkins_ami_id
  jenkins_instance_type        = var.jenkins_instance_type
  jenkins_volume_size          = var.jenkins_volume_size
  jenkins_agent_instance_type  = var.jenkins_agent_instance_type
  jenkins_agent_volume_size    = var.jenkins_agent_volume_size
  enable_jenkins_agents        = var.enable_jenkins_agents
}
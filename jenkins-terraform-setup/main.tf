provider "aws" {
  region = var.aws_region
}

module "network" {
  source = "./network"
}

module "jenkins" {
  source = "./jenkins"

  vpc_id         = module.network.vpc_id
  subnet_id      = module.network.public_subnet_id
  jenkins_ami_id = var.jenkins_ami_id
}
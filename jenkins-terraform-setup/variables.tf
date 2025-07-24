variable "aws_region" {
  default = "eu-central-1"
}

variable "jenkins_ami_id" {
  description = "AMI ID to use for the Jenkins server"
  type        = string
}
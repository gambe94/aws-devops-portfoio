variable "vpc_id" {
  description = "The VPC ID for Jenkins EC2"
  type        = string
}

variable "subnet_id" {
  description = "The subnet ID for Jenkins EC2"
  type        = string
}

variable "jenkins_ami_id" {
  description = "The AMI ID for the Jenkins server"
  type        = string
}

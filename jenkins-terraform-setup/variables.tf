variable "aws_region" {
  default = "eu-central-1"
}

variable "jenkins_ami_id" {
  description = "AMI ID to use for the Jenkins server"
  type        = string
}

variable "jenkins_instance_type" {
  description = "The instance type for the Jenkins server"
  type        = string
  default     = "t3.micro"
}

variable "jenkins_volume_size" {
  description = "The size of the EBS volume for Jenkins in GB"
  type        = number
  default     = 20
}
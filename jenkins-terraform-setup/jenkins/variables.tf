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

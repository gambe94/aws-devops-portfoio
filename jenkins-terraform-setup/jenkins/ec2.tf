# Auto-generated key pair for Jenkins master
resource "aws_key_pair" "jenkins_key" {
  key_name   = "jenkins-auto-key-${random_string.suffix.result}"
  public_key = tls_private_key.jenkins_key.public_key_openssh

  tags = {
    Name = "jenkins-auto-generated-key"
  }
}

# Generate private key
resource "tls_private_key" "jenkins_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Store private key locally for SSH access
resource "local_file" "jenkins_private_key" {
  content  = tls_private_key.jenkins_key.private_key_pem
  filename = "${path.module}/../jenkins-key.pem"
  
  provisioner "local-exec" {
    command = "chmod 400 ${path.module}/../jenkins-key.pem"
  }
}

resource "aws_instance" "jenkins" {
  ami                         = var.jenkins_ami_id
  instance_type               = var.jenkins_instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.jenkins_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.jenkins_profile.name
  associate_public_ip_address = true
  key_name                    = aws_key_pair.jenkins_key.key_name
  user_data                   = file("${path.module}/../scripts/jenkins_bootstrap.sh")

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.jenkins_volume_size
    delete_on_termination = true
    encrypted             = true
    
    tags = {
      Name = "jenkins-root-volume"
    }
  }

  tags = {
    Name        = "jenkins-server"
    Environment = "development"
    Purpose     = "CI/CD"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Elastic IP for static public IP
resource "aws_eip" "jenkins_eip" {
  instance = aws_instance.jenkins.id
  domain   = "vpc"

  tags = {
    Name = "jenkins-elastic-ip"
  }

  depends_on = [aws_instance.jenkins]
}

output "jenkins_public_ip" {
  value       = aws_eip.jenkins_eip.public_ip
  description = "Static public IP address of Jenkins server"
}

output "jenkins_private_ip" {
  value       = aws_instance.jenkins.private_ip
  description = "Private IP address of Jenkins server"
}

output "jenkins_key_name" {
  value       = aws_key_pair.jenkins_key.key_name
  description = "Name of the auto-generated key pair for Jenkins"
}

output "jenkins_ssh_command" {
  value       = "ssh -i jenkins-key.pem ec2-user@${aws_eip.jenkins_eip.public_ip}"
  description = "SSH command to connect to Jenkins master"
}

output "jenkins_instance_id" {
  value       = aws_instance.jenkins.id
  description = "Instance ID of Jenkins server"
}
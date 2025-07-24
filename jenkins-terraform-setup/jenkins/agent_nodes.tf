resource "aws_instance" "jenkins_agent_1" {
  count                       = var.enable_jenkins_agents ? 1 : 0
  ami                         = var.jenkins_ami_id
  instance_type               = var.jenkins_agent_instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.jenkins_agent_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.jenkins_agent_profile.name
  associate_public_ip_address = true
  user_data                   = templatefile("${path.module}/../scripts/jenkins_agent_bootstrap.sh", {
    jenkins_master_ip = aws_eip.jenkins_eip.public_ip
    agent_name        = "salesforce-agent"
    agent_labels      = "docker,linux,aws,nodejs,salesforce,sf-cli"
  })

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.jenkins_agent_volume_size
    delete_on_termination = true
    encrypted             = true
    
    tags = {
      Name = "jenkins-agent-1-volume"
    }
  }

  tags = {
    Name        = "jenkins-salesforce-agent"
    Environment = "development"
    Purpose     = "CI/CD Agent"
    Type        = "Salesforce Docker Agent"
  }

  depends_on = [aws_instance.jenkins]
}

# Security group for Jenkins agents
resource "aws_security_group" "jenkins_agent_sg" {
  name        = "jenkins-agent-sg"
  description = "Security group for Jenkins agents"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.jenkins_sg.id]
    description     = "SSH from Jenkins master"
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
    description     = "SSH access for management"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "jenkins-agent-security-group"
  }
}

# Outputs for agent instance
output "jenkins_agent_1_public_ip" {
  value       = var.enable_jenkins_agents ? aws_instance.jenkins_agent_1[0].public_ip : null
  description = "Public IP of Jenkins Salesforce Agent"
}

output "jenkins_agent_1_private_ip" {
  value       = var.enable_jenkins_agents ? aws_instance.jenkins_agent_1[0].private_ip : null
  description = "Private IP of Jenkins Salesforce Agent"
}

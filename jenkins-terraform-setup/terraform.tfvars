jenkins_ami_id               = "ami-09191d47657c9691a"
jenkins_instance_type        = "t3.micro"     # Free tier: 1 vCPU, 1GB RAM
jenkins_volume_size          = 20             # Free tier: up to 30GB

# Jenkins Agent Configuration (Free Tier)
jenkins_agent_instance_type  = "t3.micro"     # Free tier: 1 vCPU, 1GB RAM
jenkins_agent_volume_size    = 10             # Smaller storage for demo
enable_jenkins_agents        = true           # Enable agent nodes
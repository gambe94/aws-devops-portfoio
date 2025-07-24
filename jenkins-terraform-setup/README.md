# Jenkins Terraform Setup

This Terraform configuration deploys a Jenkins CI/CD server on AWS with enhanced features and security.

## 🚀 Features

- **Static IP**: Elastic IP ensures consistent access
- **Free Tier Optimized**: t3.micro instances (1GB RAM, 1 vCPU) for cost-effective demo
- **Encrypted Storage**: 20GB encrypted GP3 EBS volume
- **Enhanced Bootstrap**: Comprehensive setup script with error handling
- **DevOps Tools**: Pre-installed Docker, AWS CLI, and Terraform
- **Security**: IAM roles and security groups configured
- **Salesforce Agent**: Single agent node optimized for Salesforce development
- **Node.js Ready**: Full Node.js development environment with Salesforce CLI

## 📋 Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0 installed
- An AWS account with VPC permissions

## 🏗️ Infrastructure Components

### Network Module (`./network/`)
- VPC with public subnet
- Route tables and gateways
- Network ACLs

### Jenkins Module (`./jenkins/`)
- EC2 instance with Elastic IP
- Security groups (ports 22, 8080, 50000)
- IAM roles and instance profile
- Enhanced bootstrap script
- Single Salesforce agent node with Node.js and SF CLI
- Agent-specific security groups and IAM roles

## ⚙️ Configuration

### Instance Specifications (Free Tier Optimized)
- **Default Instance Type**: `t3.micro` (1 vCPU, 1GB RAM) - Free Tier Eligible
- **Storage**: 20GB encrypted GP3 volume (Free Tier: 30GB available)
- **Network**: Static public IP via Elastic IP

### Customizable Variables

```hcl
# terraform.tfvars
jenkins_ami_id               = "ami-09191d47657c9691a"  # Amazon Linux 2
jenkins_instance_type        = "t3.micro"              # Free Tier
jenkins_volume_size          = 20                      # GB

# Jenkins Agent Configuration (Free Tier)
jenkins_agent_instance_type  = "t3.micro"              # Free Tier
jenkins_agent_volume_size    = 15                      # GB
enable_jenkins_agents        = true                    # Enable/disable agents
```

### Available Instance Types
- `t3.micro`: 1 vCPU, 1GB RAM (Free Tier - recommended for demo)
- `t3.small`: 1 vCPU, 2GB RAM (low cost)
- `t3.medium`: 2 vCPUs, 4GB RAM (cost-effective)
- `t3.large`: 2 vCPUs, 8GB RAM (production workloads)

## 🚀 Deployment

1. **Initialize Terraform**:
   ```bash
   terraform init
   ```

2. **Review the plan**:
   ```bash
   terraform plan
   ```

3. **Deploy the infrastructure**:
   ```bash
   terraform apply
   ```

4. **Access Jenkins**:
   - Use the static IP provided in outputs
   - Default port: 8080
   - Get initial admin password from the logs

## 📊 Outputs

After deployment, you'll get:
- `jenkins_public_ip`: Static public IP address
- `jenkins_private_ip`: Private IP within VPC
- `jenkins_instance_id`: EC2 instance identifier
- `jenkins_agent_1_public_ip`: Public IP of Salesforce Agent
- `jenkins_agent_1_private_ip`: Private IP of Salesforce Agent

## 🔧 Post-Deployment Setup

1. **Access Jenkins**: `http://<static-ip>:8080`
2. **Initial Password**: Check bootstrap logs or EC2 system logs
3. **Install Plugins**: Recommended plugins for CI/CD
4. **Configure Security**: Set up users and permissions
5. **Setup Agents**: Follow the [Agent Setup Guide](./AGENT_SETUP.md) for Docker agent configuration

## 📦 Pre-installed Tools

The bootstrap script installs:
- **Jenkins LTS**: Latest stable version
- **Java 17**: Amazon Corretto JDK
- **Docker**: Container runtime
- **AWS CLI v2**: AWS command line tools
- **Terraform**: Infrastructure as Code
- **Git**: Version control
- **Essential utilities**: vim, htop, tree, jq

## 🔒 Security Features

- Encrypted EBS volumes
- IAM roles with least privilege
- Security groups restricting access
- Regular system updates via bootstrap script

## 📝 Maintenance

### Backup Recommendations
- Enable automated EBS snapshots
- Backup Jenkins home directory (`/var/lib/jenkins`)
- Version control Jenkins configuration as code

### Monitoring
- CloudWatch logs integration
- EC2 monitoring enabled
- Jenkins system logs in `/var/log/jenkins-bootstrap.log`

## 🆘 Troubleshooting

### Common Issues

1. **Jenkins not accessible**:
   - Check security group rules
   - Verify Elastic IP association
   - Check Jenkins service status: `sudo systemctl status jenkins`

2. **Bootstrap script failures**:
   - Check logs: `/var/log/jenkins-bootstrap.log`
   - Review EC2 instance logs in AWS Console

3. **Performance issues**:
   - Consider upgrading to `t3.xlarge`
   - Monitor memory usage with `htop`

### Useful Commands

```bash
# SSH to Jenkins server
ssh -i your-key.pem ec2-user@<static-ip>

# Check Jenkins status
sudo systemctl status jenkins

# View bootstrap logs
sudo tail -f /var/log/jenkins-bootstrap.log

# Restart Jenkins
sudo systemctl restart jenkins
```

## 💰 Cost Optimization (Free Tier)

**Monthly Cost Breakdown:**
- **Master**: t3.micro (1GB RAM) - FREE (750 hours/month)
- **Salesforce Agent**: t3.micro (1GB RAM) - FREE (750 hours/month)  
- **EBS Storage**: 30GB total - FREE (30GB included)
- **Elastic IP**: FREE (when attached to running instance)

**Total Demo Cost: 100% FREE!** 🎉

### Free Tier Optimization Tips:
- Perfect setup for Salesforce development learning
- Both instances covered by free tier
- Stop instances when not in use to save hours
- Monitor usage with AWS Cost Explorer
- Set up billing alerts for peace of mind

## 🔄 Updates

To update the infrastructure:
1. Modify variables in `terraform.tfvars`
2. Run `terraform plan` to review changes
3. Apply with `terraform apply`

## 🛠️ Free Tier Management

Use the included management script to optimize costs:

```bash
# Make script executable
chmod +x manage-jenkins.sh

# Check current status and costs
./manage-jenkins.sh status

# Stop agents when not building (saves money)
./manage-jenkins.sh stop agents

# Start only what you need
./manage-jenkins.sh start master

# Get help
./manage-jenkins.sh help
```

---

**Note**: The Elastic IP ensures your Jenkins server maintains the same public IP address even after restarts or rebuilds, making it perfect for webhook configurations and DNS setup.

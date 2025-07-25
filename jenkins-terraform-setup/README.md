# Jenkins Terraform Setup

This Terraform configuration deploys a Jenkins CI/CD server on AWS with enhanced features and security.

## 🚀 Features

- **Static IP**: Elastic IP ensures consistent access
- **Free Tier Optimized**: t3.micro instances (1GB RAM, 1 vCPU) for cost-effective demo
- **Encrypted Storage**: 20GB encrypted GP3 EBS volume
- **Enhanced Bootstrap**: Comprehensive setup script with error handling
- **DevOps Tools**: Pre-installed Docker, AWS CLI, and Terraform
- **Security**: IAM roles and security groups configured
- **Built-in Executors**: Jenkins master can run builds directly

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
- Security groups (ports 22, 8080)
- IAM roles and instance profile
- Enhanced bootstrap script

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
   - **Web UI**: Use the static IP provided in outputs (port 8080)
   - **SSH Access**: Use the auto-generated `jenkins-key.pem` file
   - **Key Location**: Created automatically in your project directory
   - **Initial Password**: Retrieved from bootstrap logs

> **🔑 SSH Key**: No manual key pair creation needed! Terraform automatically generates `jenkins-key.pem` for secure access.

## 📊 Outputs

After deployment, you'll get:
- `jenkins_public_ip`: Static public IP address
- `jenkins_private_ip`: Private IP within VPC
- `jenkins_instance_id`: EC2 instance identifier
- `jenkins_key_name`: Auto-generated key pair name
- `jenkins_ssh_command`: Ready-to-use SSH command

## 🔧 Post-Deployment Setup

1. **Access Jenkins Web UI**: `http://<static-ip>:8080`
2. **SSH Access**: Use the auto-generated key: `ssh -i jenkins-key.pem ec2-user@<public-ip>`
3. **Initial Password**: Check bootstrap logs or run `sudo cat /var/lib/jenkins/secrets/initialAdminPassword`
4. **Install Plugins**: Recommended plugins for CI/CD
5. **Configure Security**: Set up users and permissions
6. **Create Jobs**: Start building your CI/CD pipelines

> **Note**: The `jenkins-key.pem` file is automatically created in your project directory for SSH access.

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

- **Auto-generated SSH Keys**: No need to create key pairs manually
- **Encrypted EBS volumes**: Data at rest encryption
- **IAM roles with least privilege**: Minimal required permissions
- **Security groups**: Restricting access to necessary ports only
- **Regular system updates**: Via bootstrap script

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

4. **Disk space warning on /tmp**:
   - Jenkins shows "/tmp space below 1GB" even with 30GB available
   - This is because `/tmp` is a separate tmpfs filesystem (453MB)
   - Fix: Configure Jenkins to use custom temp directory on main volume

### Fix /tmp Disk Space Warning

```bash
# SSH to Jenkins server
ssh -i jenkins-key.pem ec2-user@<jenkins-ip>

# Create custom temp directory
sudo mkdir -p /var/lib/jenkins/tmp
sudo chown jenkins:jenkins /var/lib/jenkins/tmp
sudo chmod 755 /var/lib/jenkins/tmp

# Configure Jenkins to use custom temp directory
sudo mkdir -p /etc/systemd/system/jenkins.service.d
sudo tee /etc/systemd/system/jenkins.service.d/override.conf > /dev/null << 'EOF'
[Service]
Environment="JAVA_OPTS=-Djava.awt.headless=true -Xms256m -Xmx512m -Djava.io.tmpdir=/var/lib/jenkins/tmp"
EOF

# Reload systemd and restart Jenkins
sudo systemctl daemon-reload
sudo systemctl restart jenkins

# Verify the fix
sudo systemctl status jenkins
```

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
- **Jenkins Master**: t3.micro (1GB RAM) - FREE (750 hours/month)  
- **EBS Storage**: 20GB total - FREE (30GB included)
- **Elastic IP**: FREE (when attached to running instance)

**Total Demo Cost: 100% FREE!** 🎉

### Free Tier Optimization Tips:
- Perfect setup for learning Jenkins and CI/CD
- Single instance covered by free tier
- Stop instance when not in use to save hours
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

# Stop Jenkins when not in use (saves money)
./manage-jenkins.sh stop

# Start Jenkins when needed
./manage-jenkins.sh start

# Get help
./manage-jenkins.sh help
```

---

**Note**: The Elastic IP ensures your Jenkins server maintains the same public IP address even after restarts or rebuilds, making it perfect for webhook configurations and DNS setup.

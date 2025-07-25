# Quick Start Guide

## Auto-Generated SSH Access Setup

Your Jenkins infrastructure now includes **automatic SSH key generation**! No manual key pair creation needed.

### What's New:
✅ **Auto-generated SSH Key Pair**: `jenkins-key.pem` created automatically  
✅ **Ready-to-use SSH Commands**: Available in terraform outputs  
✅ **Secure Management Script**: Enhanced with SSH access features  
✅ **No Manual Setup**: Everything configured automatically  

### Quick Commands:

```bash
# Deploy infrastructure (creates jenkins-key.pem automatically)
terraform apply

# Check status and get access info
./manage-jenkins.sh status

# Connect via SSH (no manual key setup needed!)
./manage-jenkins.sh ssh

# Get Jenkins initial password
./manage-jenkins.sh password

# View Jenkins logs
./manage-jenkins.sh logs

# Stop Jenkins to save free tier hours
./manage-jenkins.sh stop
```

### Access Methods:

1. **Web UI**: `http://<jenkins-public-ip>:8080`
2. **SSH**: `ssh -i jenkins-key.pem ec2-user@<jenkins-public-ip>`
3. **Management Script**: `./manage-jenkins.sh ssh`

### File Locations:
- **SSH Private Key**: `jenkins-key.pem` (in project root)
- **Management Script**: `manage-jenkins.sh`
- **Terraform State**: `terraform.tfstate`

### Security Notes:
- `jenkins-key.pem` is auto-generated with proper 400 permissions
- Private key is added to `.gitignore` to prevent accidental commits
- Key is unique per deployment (includes random suffix)

### Free Tier Optimization:
- Use `./manage-jenkins.sh stop` when not using Jenkins
- Monitor usage with `./manage-jenkins.sh status`
- 750 free hours per month available

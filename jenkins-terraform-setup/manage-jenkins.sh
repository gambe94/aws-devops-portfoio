#!/bin/bash
# Jenkins Free Tier Management Script
# This script helps you manage your Jenkins infrastructure to optimize AWS Free Tier usage

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if AWS CLI is configured
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed or not in PATH"
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS CLI is not configured. Run 'aws configure' first."
        exit 1
    fi
}

# Get instance IDs from Terraform output
get_instance_ids() {
    print_info "Getting instance IDs from Terraform..."
    
    if [ ! -f terraform.tfstate ]; then
        print_error "terraform.tfstate file not found. Make sure you're in the terraform directory and have deployed the infrastructure."
        exit 1
    fi
    
    JENKINS_MASTER_ID=$(terraform output -raw jenkins_instance_id 2>/dev/null || echo "")
    JENKINS_PUBLIC_IP=$(terraform output -raw jenkins_public_ip 2>/dev/null || echo "")
    
    if [ -z "$JENKINS_MASTER_ID" ]; then
        print_error "Could not find Jenkins master instance ID"
        exit 1
    fi
    
    print_info "Jenkins Master ID: $JENKINS_MASTER_ID"
    print_info "Jenkins Public IP: $JENKINS_PUBLIC_IP"
}

# Get instance status
get_instance_status() {
    local instance_id=$1
    local instance_name=$2
    
    if [ -n "$instance_id" ]; then
        local status=$(aws ec2 describe-instances --instance-ids "$instance_id" --query 'Reservations[*].Instances[*].State.Name' --output text 2>/dev/null || echo "not-found")
        echo "$instance_name: $status"
    else
        echo "$instance_name: not-found"
    fi
}

# Display current status
status() {
    print_info "Current Jenkins Infrastructure Status:"
    echo "=================================="
    get_instance_status "$JENKINS_MASTER_ID" "Jenkins Master"
    echo ""
    
    # Check instance state
    local state=$(aws ec2 describe-instances --instance-ids "$JENKINS_MASTER_ID" --query 'Reservations[*].Instances[*].State.Name' --output text 2>/dev/null || echo "not-found")
    
    print_info "Access Information:"
    echo "Web UI: http://$JENKINS_PUBLIC_IP:8080"
    if [ -f "jenkins-key.pem" ]; then
        echo "SSH: ssh -i jenkins-key.pem ec2-user@$JENKINS_PUBLIC_IP"
    else
        print_warning "jenkins-key.pem not found in current directory"
    fi
    echo ""
    
    print_info "Cost Estimation:"
    if [ "$state" = "running" ]; then
        echo "Running instances: 1"
        print_info "✅ You're within FREE TIER limits! (750 hours/month available)"
    else
        echo "Running instances: 0"
        print_info "✅ No charges - instance is stopped"
    fi
}

# Start Jenkins instance
start() {
    if [ -n "$JENKINS_MASTER_ID" ]; then
        print_info "Starting Jenkins Master..."
        aws ec2 start-instances --instance-ids "$JENKINS_MASTER_ID"
        print_info "Jenkins Master starting. It may take a few minutes to be fully ready."
        print_info "Access Jenkins at: http://$JENKINS_PUBLIC_IP:8080"
        if [ -f "jenkins-key.pem" ]; then
            print_info "SSH access: ssh -i jenkins-key.pem ec2-user@$JENKINS_PUBLIC_IP"
        fi
    else
        print_error "Jenkins Master instance ID not found"
    fi
}

# Stop Jenkins instance
stop() {
    if [ -n "$JENKINS_MASTER_ID" ]; then
        print_info "Stopping Jenkins Master..."
        aws ec2 stop-instances --instance-ids "$JENKINS_MASTER_ID"
        print_info "Jenkins Master stopping. This saves your free tier hours!"
    else
        print_error "Jenkins Master instance ID not found"
    fi
}

# Restart Jenkins instance
restart() {
    print_info "Restarting Jenkins Master..."
    stop
    sleep 10
    start
}

# Connect via SSH
ssh_connect() {
    if [ ! -f "jenkins-key.pem" ]; then
        print_error "jenkins-key.pem not found in current directory"
        print_info "Make sure you're running this from the terraform project directory"
        exit 1
    fi
    
    print_info "Connecting to Jenkins Master via SSH..."
    ssh -i jenkins-key.pem ec2-user@"$JENKINS_PUBLIC_IP"
}

# Get Jenkins initial password
get_password() {
    if [ ! -f "jenkins-key.pem" ]; then
        print_error "jenkins-key.pem not found in current directory"
        exit 1
    fi
    
    print_info "Getting Jenkins initial admin password..."
    ssh -i jenkins-key.pem ec2-user@"$JENKINS_PUBLIC_IP" "sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
}

# Get Jenkins logs
logs() {
    if [ ! -f "jenkins-key.pem" ]; then
        print_error "jenkins-key.pem not found in current directory"
        exit 1
    fi
    
    print_info "Getting Jenkins system logs..."
    ssh -i jenkins-key.pem ec2-user@"$JENKINS_PUBLIC_IP" "sudo journalctl -u jenkins -f"
}

# Fix Jenkins temp directory issue
fix_temp() {
    if [ ! -f "jenkins-key.pem" ]; then
        print_error "jenkins-key.pem not found in current directory"
        exit 1
    fi
    
    print_info "Fixing Jenkins temp directory configuration..."
    ssh -i jenkins-key.pem ec2-user@"$JENKINS_PUBLIC_IP" << 'EOF'
# Create custom temp directory
sudo mkdir -p /var/lib/jenkins/tmp
sudo chown jenkins:jenkins /var/lib/jenkins/tmp
sudo chmod 755 /var/lib/jenkins/tmp

# Configure Jenkins to use custom temp directory via systemd
sudo mkdir -p /etc/systemd/system/jenkins.service.d
sudo tee /etc/systemd/system/jenkins.service.d/override.conf > /dev/null << 'OVERRIDE_EOF'
[Service]
Environment="JAVA_OPTS=-Djava.awt.headless=true -Xms256m -Xmx512m -Djava.io.tmpdir=/var/lib/jenkins/tmp"
OVERRIDE_EOF

# Reload systemd and restart Jenkins
sudo systemctl daemon-reload
sudo systemctl restart jenkins

echo "Jenkins temp directory fix applied. Jenkins is restarting..."
echo "Wait 30 seconds then check Jenkins web UI to verify the disk space warning is gone."
EOF
    
    print_info "Fix applied! Jenkins should restart and use /var/lib/jenkins/tmp instead of /tmp"
    print_info "Check Jenkins web UI in 30 seconds to verify the disk space warning is resolved"
}

# Fix Jenkins plugin dependency issues
fix_plugins() {
    if [ ! -f "jenkins-key.pem" ]; then
        print_error "jenkins-key.pem not found in current directory"
        exit 1
    fi
    
    print_info "Fixing Jenkins plugin dependency issues..."
    ssh -i jenkins-key.pem ec2-user@"$JENKINS_PUBLIC_IP" << 'EOF'
# Stop Jenkins
sudo systemctl stop jenkins

# Remove problematic Blue Ocean plugins to clean up dependencies
sudo rm -rf /var/lib/jenkins/plugins/blueocean*

# Restart Jenkins to clean up plugin state
sudo systemctl start jenkins

echo "Problematic Blue Ocean plugins removed. Jenkins is starting..."
echo "Wait 60 seconds, then reinstall Blue Ocean via Jenkins web UI if needed."
echo "Go to Manage Jenkins > Manage Plugins > Available > Search for 'Blue Ocean'"
EOF
    
    print_info "Plugin cleanup completed!"
    print_info "Steps to complete the fix:"
    print_info "1. Wait 60 seconds for Jenkins to fully start"
    print_info "2. Go to Jenkins web UI: http://$JENKINS_PUBLIC_IP:8080"
    print_info "3. Navigate to: Manage Jenkins > Manage Plugins"
    print_info "4. If you want Blue Ocean: Go to 'Available' tab, search 'Blue Ocean', install it"
    print_info "5. Or just use standard Jenkins UI (Blue Ocean is optional)"
}

# Show help
show_help() {
    echo "Jenkins Free Tier Management Script"
    echo "==================================="
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  status       Show current status of Jenkins infrastructure"
    echo "  start        Start Jenkins master instance"
    echo "  stop         Stop Jenkins master instance"
    echo "  restart      Restart Jenkins master instance"
    echo "  ssh          Connect to Jenkins master via SSH"
    echo "  password     Get Jenkins initial admin password"
    echo "  logs         Show Jenkins system logs"
    echo "  fix-temp     Fix Jenkins /tmp disk space warning"
    echo "  fix-plugins  Fix Jenkins plugin dependency issues"
    echo "  help         Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 status           # Check what's running"
    echo "  $0 stop             # Stop Jenkins to save free tier hours"
    echo "  $0 start            # Start Jenkins when you need it"
    echo "  $0 ssh              # SSH into Jenkins master"
    echo "  $0 password         # Get initial admin password"
    echo ""
    echo "Free Tier Tips:"
    echo "  - Stop Jenkins when not in use to save your 750 free hours/month"
    echo "  - One t3.micro instance = ~$8.50/month after free tier"
    echo "  - Use 'status' to monitor your usage"
    echo ""
    echo "SSH Key:"
    echo "  - Auto-generated jenkins-key.pem is used for all SSH connections"
    echo "  - Key is created automatically during 'terraform apply'"
}

# Main script logic
main() {
    local command=${1:-help}
    
    case $command in
        "status")
            check_aws_cli
            get_instance_ids
            status
            ;;
        "start")
            check_aws_cli
            get_instance_ids
            start
            ;;
        "stop")
            check_aws_cli
            get_instance_ids
            stop
            ;;
        "restart")
            check_aws_cli
            get_instance_ids
            restart
            ;;
        "ssh")
            check_aws_cli
            get_instance_ids
            ssh_connect
            ;;
        "password")
            check_aws_cli
            get_instance_ids
            get_password
            ;;
        "logs")
            check_aws_cli
            get_instance_ids
            logs
            ;;
        "fix-temp")
            check_aws_cli
            get_instance_ids
            fix_temp
            ;;
        "fix-plugins")
            check_aws_cli
            get_instance_ids
            fix_plugins
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run the script
main "$@"

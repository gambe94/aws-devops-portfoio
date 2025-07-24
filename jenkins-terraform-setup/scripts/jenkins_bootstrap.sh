#!/bin/bash
# Enhanced Jenkins bootstrap script with improved error handling and logging

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Setup logging
LOGFILE="/var/log/jenkins-bootstrap.log"
exec > >(tee -a "$LOGFILE")
exec 2>&1

echo "=== Jenkins Bootstrap Script Started at $(date) ==="

# Function for error handling
handle_error() {
    echo "ERROR: An error occurred on line $1"
    echo "Bootstrap script failed at $(date)"
    exit 1
}

trap 'handle_error $LINENO' ERR

# Update system packages
echo "Updating system packages..."
sudo yum update -y

# Install essential tools (handle curl conflict)
echo "Installing essential tools..."
sudo yum install -y \
    wget \
    git \
    unzip \
    vim \
    htop \
    tree \
    jq

# Handle curl conflict by using curl-minimal (which is already installed)
echo "Checking curl installation..."
if ! command -v curl &> /dev/null; then
    echo "Installing curl (removing curl-minimal first)..."
    sudo yum remove -y curl-minimal     
    sudo yum install -y curl
else
    echo "curl is already available via curl-minimal"
fi

# Add Jenkins repository and import GPG key (following official Red Hat docs)
echo "Adding Jenkins repository..."
sudo wget -O /etc/yum.repos.d/jenkins.repo \
    https://pkg.jenkins.io/redhat-stable/jenkins.repo

# Import Jenkins GPG key with the correct 2023 key
echo "Importing Jenkins GPG key..."
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

# Install required dependencies for Jenkins (as per official docs)
echo "Installing Jenkins dependencies..."
sudo yum install -y fontconfig

# Upgrade all packages
echo "Upgrading packages..."
sudo yum upgrade -y

# Install Java 17 Amazon Corretto
echo "Installing Java 17..."
sudo yum install -y java-17-amazon-corretto-devel

# Verify Java installation
echo "Java version installed:"
java -version

# Set JAVA_HOME environment variable globally
echo "Setting JAVA_HOME..."
JAVA_HOME_PATH="/usr/lib/jvm/java-17-amazon-corretto.x86_64"
echo "export JAVA_HOME=$JAVA_HOME_PATH" | sudo tee /etc/environment
echo "export PATH=\$PATH:\$JAVA_HOME/bin" | sudo tee -a /etc/environment

# Install Jenkins (following official Red Hat documentation)
echo "Installing Jenkins..."
sudo yum install -y jenkins

# Configure Jenkins
echo "Configuring Jenkins..."

# Set JAVA_HOME in Jenkins config if file exists
if [ -f /etc/sysconfig/jenkins ]; then
    sudo sed -i "s|^#JAVA_HOME.*|JAVA_HOME=$JAVA_HOME_PATH|" /etc/sysconfig/jenkins
    sudo sed -i "s|^JAVA_HOME.*|JAVA_HOME=$JAVA_HOME_PATH|" /etc/sysconfig/jenkins
    
    # Optimize Jenkins memory allocation for t3.micro (1GB RAM)
    sudo sed -i 's/^JENKINS_JAVA_OPTIONS=.*/JENKINS_JAVA_OPTIONS="-Djava.awt.headless=true -Xms256m -Xmx512m"/' /etc/sysconfig/jenkins
fi

# Create Jenkins directories with proper permissions
sudo mkdir -p /var/lib/jenkins/logs
sudo chown -R jenkins:jenkins /var/lib/jenkins
sudo chmod -R 755 /var/lib/jenkins

# Install Docker (useful for Jenkins agents and builds)
echo "Installing Docker..."
sudo yum install -y docker
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker jenkins


# Reload systemd daemon
sudo systemctl daemon-reload

# Enable and start Jenkins service
echo "Starting Jenkins service..."
sudo systemctl enable jenkins
sudo systemctl start jenkins

# Wait for Jenkins to start up
echo "Waiting for Jenkins to start..."
sleep 30

# Check Jenkins status
echo "Jenkins service status:"
sudo systemctl status jenkins --no-pager

# Get Jenkins initial admin password
echo "=== IMPORTANT: Jenkins Initial Setup ==="
if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
    echo "Jenkins initial admin password:"
    sudo cat /var/lib/jenkins/secrets/initialAdminPassword
    echo ""
    echo "Access Jenkins at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
else
    echo "Warning: Initial admin password file not found. Jenkins may still be starting up."
fi

# Display useful information
echo ""
echo "=== Installation Summary ==="
echo "Java version: $(java -version 2>&1 | head -n 1)"
echo "Docker version: $(docker --version)"
echo "AWS CLI version: $(aws --version)"
echo "Terraform version: $(terraform --version | head -n 1)"
echo "Jenkins service: $(sudo systemctl is-active jenkins)"
echo ""
echo "Log file location: $LOGFILE"
echo "Jenkins home: /var/lib/jenkins"
echo "Jenkins config: /etc/sysconfig/jenkins"
echo ""
echo "=== Jenkins Bootstrap Script Completed Successfully at $(date) ==="
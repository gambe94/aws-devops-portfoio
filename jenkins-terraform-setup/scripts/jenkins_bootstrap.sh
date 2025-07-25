#!/bin/bash
# Jenkins bootstrap script following official AWS tutorial
# Source: https://www.jenkins.io/doc/tutorials/tutorial-for-installing-jenkins-on-AWS/

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Setup logging
LOGFILE="/var/log/jenkins-bootstrap.log"
exec > >(tee -a "$LOGFILE")
exec 2>&1

echo "=== Jenkins Bootstrap Script Started at $(date) ==="
echo "Following official Jenkins AWS tutorial steps"

# Function for error handling
handle_error() {
    echo "ERROR: An error occurred on line $1"
    echo "Bootstrap script failed at $(date)"
    exit 1
}

trap 'handle_error $LINENO' ERR

# Step 1: Ensure that your software packages are up to date (official tutorial)
echo "Step 1: Performing quick software update..."
sudo yum update -y

# Step 2: Add the Jenkins repo (official tutorial)
echo "Step 2: Adding Jenkins repository..."
sudo wget -O /etc/yum.repos.d/jenkins.repo \
    https://pkg.jenkins.io/redhat-stable/jenkins.repo

# Step 3: Import a key file from Jenkins-CI (official tutorial)
echo "Step 3: Importing Jenkins key file..."
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
sudo yum upgrade

# Step 4: Install Java (official tutorial)
echo "Step 4: Installing Java..."
sudo yum install java-17-amazon-corretto -y

# Step 5: Install Jenkins (official tutorial)
echo "Step 5: Installing Jenkins..."
sudo yum install jenkins -y

# Step 6: Enable the Jenkins service to start at boot (official tutorial)
echo "Step 6: Enabling Jenkins service..."
sudo systemctl enable jenkins

# Step 7: Start Jenkins as a service (official tutorial)
echo "Step 7: Starting Jenkins service..."
sudo systemctl start jenkins

# Step 8: Check the status of the Jenkins service (official tutorial)
echo "Step 8: Checking Jenkins service status..."
sudo systemctl status jenkins --no-pager

# === Additional setup for production environment ===
echo ""
echo "=== Additional Production Setup ==="

# Install essential development tools 
echo "Installing essential development tools..."
sudo yum install -y git wget unzip vim


# Verify Java installation
echo "Verifying Java installation..."
java -version

# Install Docker for containerized builds
echo "Installing Docker..."
sudo yum install -y docker
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker jenkins

# Optimize Jenkins for t3.micro instance (1GB RAM)
echo "Optimizing Jenkins configuration for t3.micro..."
JAVA_HOME_PATH="/usr/lib/jvm/java-17-amazon-corretto"
if [ -f /etc/sysconfig/jenkins ]; then
    sudo sed -i "s|^#JAVA_HOME.*|JAVA_HOME=$JAVA_HOME_PATH|" /etc/sysconfig/jenkins
    sudo sed -i "s|^JAVA_HOME.*|JAVA_HOME=$JAVA_HOME_PATH|" /etc/sysconfig/jenkins
    
    # Set memory limits for t3.micro and configure temp directory
    sudo sed -i 's/^JENKINS_JAVA_OPTIONS=.*/JENKINS_JAVA_OPTIONS="-Djava.awt.headless=true -Xms256m -Xmx512m -Djava.io.tmpdir=\/var\/lib\/jenkins\/tmp"/' /etc/sysconfig/jenkins
    
    # Create Jenkins temp directory with proper permissions
    sudo mkdir -p /var/lib/jenkins/tmp
    sudo chown jenkins:jenkins /var/lib/jenkins/tmp
    sudo chmod 755 /var/lib/jenkins/tmp
    
    # Restart Jenkins to apply new settings
    echo "Restarting Jenkins to apply configuration..."
    sudo systemctl restart jenkins
    sleep 30
fi

# Create proper Jenkins directories
sudo mkdir -p /var/lib/jenkins/logs
sudo chown -R jenkins:jenkins /var/lib/jenkins
sudo chmod -R 755 /var/lib/jenkins

# Wait for Jenkins to be fully ready
echo "Waiting for Jenkins to be fully ready..."
sleep 45

# Display Jenkins initial admin password (as per official tutorial)
echo ""
echo "=== Jenkins Initial Setup (Official Tutorial) ==="
if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
    echo "Jenkins initial admin password (use this to unlock Jenkins):"
    sudo cat /var/lib/jenkins/secrets/initialAdminPassword
    echo ""
    echo "Access Jenkins at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
    echo ""
    echo "Next steps from official tutorial:"
    echo "1. Connect to http://<your_server_public_DNS>:8080 from your browser"
    echo "2. Enter the password shown above"
    echo "3. Click 'Install suggested plugins'"
    echo "4. Create your first admin user"
    echo "5. Complete Jenkins setup"
else
    echo "Warning: Initial admin password file not found."
    echo "Jenkins may still be starting up. Try running:"
    echo "sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
fi

# Display installation summary
echo ""
echo "=== Installation Summary ==="
echo "✅ Jenkins installation: Complete (following official AWS tutorial)"
echo "✅ Java version: $(java -version 2>&1 | head -n 1)"
echo "✅ Jenkins service: $(sudo systemctl is-active jenkins)"
echo "✅ Docker: $(docker --version 2>/dev/null || echo 'Installed')"
echo ""
echo "📋 Log file: $LOGFILE"
echo "🏠 Jenkins home: /var/lib/jenkins"
echo "⚙️  Jenkins config: /etc/sysconfig/jenkins"
echo "🌐 Jenkins URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo ""
echo "=== Jenkins Bootstrap Script Completed Successfully at $(date) ==="
echo "Script follows: https://www.jenkins.io/doc/tutorials/tutorial-for-installing-jenkins-on-AWS/"
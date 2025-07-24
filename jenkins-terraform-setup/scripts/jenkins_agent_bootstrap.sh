#!/bin/bash
# Jenkins Agent Bootstrap Script with Docker support

set -euo pipefail

# Setup logging
LOGFILE="/var/log/jenkins-agent-bootstrap.log"
exec > >(tee -a "$LOGFILE")
exec 2>&1

echo "=== Jenkins Agent Bootstrap Script Started at $(date) ==="

# Get parameters from template
JENKINS_MASTER_IP="${jenkins_master_ip}"
AGENT_NAME="${agent_name}"
AGENT_LABELS="${agent_labels}"

echo "Configuring Jenkins Agent: $AGENT_NAME"
echo "Jenkins Master IP: $JENKINS_MASTER_IP"
echo "Agent Labels: $AGENT_LABELS"

# Function for error handling
handle_error() {
    echo "ERROR: An error occurred on line $1"
    echo "Agent bootstrap script failed at $(date)"
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
    jq \
    nc

# Handle curl conflict by using curl-minimal (which is already installed)
echo "Checking curl installation..."
if ! command -v curl &> /dev/null; then
    echo "Installing curl (removing curl-minimal first)..."
    sudo yum remove -y curl-minimal
    sudo yum install -y curl
else
    echo "curl is already available via curl-minimal"
fi

# Install Java 17 Amazon Corretto
echo "Installing Java 17..."
sudo yum install -y java-17-amazon-corretto-devel

# Set JAVA_HOME environment variable
JAVA_HOME_PATH="/usr/lib/jvm/java-17-amazon-corretto.x86_64"
echo "export JAVA_HOME=$JAVA_HOME_PATH" | sudo tee /etc/environment
echo "export PATH=\$PATH:\$JAVA_HOME/bin" | sudo tee -a /etc/environment

# Verify Java installation
echo "Java version installed:"
java -version

# Install Docker
echo "Installing Docker..."
sudo yum install -y docker
sudo systemctl enable docker
sudo systemctl start docker

# Create jenkins user and add to docker group
echo "Creating Jenkins user..."
sudo useradd -m -s /bin/bash jenkins || true
sudo usermod -aG docker jenkins

# Create Jenkins agent directory
sudo mkdir -p /home/jenkins/agent
sudo chown -R jenkins:jenkins /home/jenkins
sudo chmod 755 /home/jenkins/agent

# Install Docker Compose
echo "Installing Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install AWS CLI v2
echo "Installing AWS CLI v2..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip

# Install Terraform
echo "Installing Terraform..."
TERRAFORM_VERSION="1.7.5"
wget "https://releases.hashicorp.com/terraform/$${TERRAFORM_VERSION}/terraform_$${TERRAFORM_VERSION}_linux_amd64.zip"
unzip "terraform_$${TERRAFORM_VERSION}_linux_amd64.zip"
sudo mv terraform /usr/local/bin/
rm "terraform_$${TERRAFORM_VERSION}_linux_amd64.zip"

# Install kubectl
echo "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# Install Node.js and npm (using NodeSource repository)
echo "Installing Node.js..."
curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
sudo yum install -y nodejs

# Verify Node.js installation
echo "Node.js version installed:"
node --version
npm --version

# Install Salesforce CLI
echo "Installing Salesforce CLI..."
npm install -g @salesforce/cli

# Verify Salesforce CLI installation
echo "Salesforce CLI version installed:"
sf --version

# Install additional Node.js development tools
echo "Installing Node.js development tools..."
npm install -g yarn
npm install -g typescript
npm install -g @angular/cli
npm install -g create-react-app

# Download Jenkins agent JAR
echo "Downloading Jenkins agent JAR..."
sudo -u jenkins wget -O /home/jenkins/agent/agent.jar "http://$JENKINS_MASTER_IP:8080/jnlpJars/agent.jar" || {
    echo "Warning: Could not download agent.jar yet. Jenkins master may still be starting up."
}

# Create agent startup script
echo "Creating agent startup script..."
cat << 'EOF' | sudo tee /home/jenkins/start-agent.sh
#!/bin/bash
# Jenkins Agent Startup Script

JENKINS_MASTER_IP="${jenkins_master_ip}"
AGENT_NAME="${agent_name}"
AGENT_LABELS="${agent_labels}"

# Wait for Jenkins master to be ready
echo "Waiting for Jenkins master to be ready..."
while ! nc -z $JENKINS_MASTER_IP 8080; do
    echo "Jenkins master not ready yet, waiting 30 seconds..."
    sleep 30
done

echo "Jenkins master is ready! Starting agent..."

# Download agent.jar if not exists
if [ ! -f /home/jenkins/agent/agent.jar ]; then
    echo "Downloading agent.jar..."
    wget -O /home/jenkins/agent/agent.jar "http://$JENKINS_MASTER_IP:8080/jnlpJars/agent.jar"
fi

cd /home/jenkins/agent

# Note: The secret and node name will need to be configured manually in Jenkins UI
# This script provides the foundation for manual agent connection
echo "Agent is ready to connect to Jenkins master at $JENKINS_MASTER_IP:8080"
echo "Agent Name: $AGENT_NAME"
echo "Agent Labels: $AGENT_LABELS"
echo "Working Directory: /home/jenkins/agent"
echo ""
echo "To complete the setup:"
echo "1. Go to Jenkins UI: http://$JENKINS_MASTER_IP:8080"
echo "2. Navigate to Manage Jenkins > Manage Nodes and Clouds"
echo "3. Create a new node with name: $AGENT_NAME"
echo "4. Set labels: $AGENT_LABELS"
echo "5. Set remote root directory: /home/jenkins/agent"
echo "6. Launch method: Launch agent by connecting it to the master"
echo "7. Use the provided command to connect this agent"

EOF

sudo chmod +x /home/jenkins/start-agent.sh
sudo chown jenkins:jenkins /home/jenkins/start-agent.sh

# Create systemd service for the agent startup script
cat << EOF | sudo tee /etc/systemd/system/jenkins-agent-ready.service
[Unit]
Description=Jenkins Agent Ready Service
After=network.target docker.service

[Service]
Type=oneshot
User=jenkins
ExecStart=/home/jenkins/start-agent.sh
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable jenkins-agent-ready.service

# Install essential Docker images for Node.js and Salesforce development
echo "Pulling essential Docker images..."
sudo docker pull salesforce/salesforcedx:latest-full

# Set up Docker daemon configuration for better performance
echo "Configuring Docker daemon..."
sudo mkdir -p /etc/docker
cat << EOF | sudo tee /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ]
}
EOF

sudo systemctl restart docker

# Display useful information
echo ""
echo "=== Agent Installation Summary ==="
echo "Java version: $(java -version 2>&1 | head -n 1)"
echo "Docker version: $(docker --version)"
echo "Docker Compose version: $(docker-compose --version)"
echo "AWS CLI version: $(aws --version)"
echo "Terraform version: $(terraform --version | head -n 1)"
echo "kubectl version: $(kubectl version --client --short 2>/dev/null || echo 'kubectl client installed')"
echo ""
echo "Agent Name: $AGENT_NAME"
echo "Agent Labels: $AGENT_LABELS"
echo "Working Directory: /home/jenkins/agent"
echo "Jenkins Master: http://$JENKINS_MASTER_IP:8080"
echo ""
echo "Log file location: $LOGFILE"

# Start the ready service
sudo systemctl start jenkins-agent-ready.service

echo "=== Jenkins Agent Bootstrap Script Completed Successfully at $(date) ==="

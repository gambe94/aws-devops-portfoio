#!/bin/bash
# Bash script to bootstrap Jenkins installation 

sudo yum update -y

# Add Jenkins repo and import key
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key

# Upgrade packages
sudo yum upgrade -y

# Install Java 17 Amazon Corretto
sudo yum install -y java-17-amazon-corretto

# Verify Java installed
java -version

# Set JAVA_HOME for Jenkins in its config
sudo sed -i '/^#JAVA_HOME/c\JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto.x86_64' /etc/sysconfig/jenkins

# Reload systemd config in case any service files changed
sudo systemctl daemon-reload

# Install Jenkins
sudo yum install -y jenkins

# Enable and start Jenkins service
sudo systemctl enable jenkins
sudo systemctl start jenkins

# Optionally show Jenkins status
sudo systemctl status jenkins
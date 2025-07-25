# Jenkins Salesforce Agent Setup Guide

This guide explains how to configure a Jenkins agent node with Docker and Salesforce CLI support after your infrastructure is deployed.

## 🏗️ Infrastructure Overview

After running `terraform apply`, you'll have:
- **Jenkins Master**: Main Jenkins server with web UI
- **Salesforce Agent**: `salesforce-agent` with labels: `docker,linux,aws,nodejs,salesforce,sf-cli`

## 📋 Agent Configuration Steps

### 1. Access Jenkins Master

1. Get the Jenkins master IP from Terraform outputs:
   ```bash
   terraform output jenkins_public_ip
   ```

2. Open Jenkins in your browser:
   ```
   http://<jenkins_public_ip>:8080
   ```

3. Get the initial admin password:
   - SSH to Jenkins master: `ssh -i your-key.pem ec2-user@<jenkins_public_ip>`
   - View password: `sudo cat /var/lib/jenkins/secrets/initialAdminPassword`

### 2. Install Required Plugins

1. Go to **Manage Jenkins** → **Manage Plugins**
2. Install these plugins if not already installed:
   - **Docker Pipeline**
   - **Docker plugin**
   - **SSH Build Agents**
   - **NodeJS Plugin**
   - **Blue Ocean** (recommended)

### 3. Configure Agent Node

#### For Salesforce Agent (salesforce-agent):

1. Go to **Manage Jenkins** → **Manage Nodes and Clouds**
2. Click **New Node**
3. Configure:
   - **Node name**: `salesforce-agent`
   - **Type**: Permanent Agent
   - **Number of executors**: `1` (optimized for t3.micro)
   - **Remote root directory**: `/home/jenkins/agent`
   - **Labels**: `docker linux aws nodejs salesforce sf-cli`
   - **Usage**: Use this node as much as possible
   - **Launch method**: Launch agents via SSH
   - **Host**: Get from `terraform output jenkins_agent_1_public_ip`
   - **Credentials**: Add SSH key for `jenkins` user
   - **Host Key Verification Strategy**: Non verifying Verification Strategy

## 🔐 SSH Key Setup

### Option 1: Using EC2 Key Pair (Recommended)

1. In Jenkins credentials, add your EC2 private key:
   - **Kind**: SSH Username with private key
   - **Username**: `jenkins`
   - **Private Key**: Upload your EC2 key pair private key

### Option 2: Generate New SSH Keys

1. SSH to Jenkins master
2. Generate SSH key pair:
   ```bash
   sudo -u jenkins ssh-keygen -t rsa -b 4096 -f /var/lib/jenkins/.ssh/id_rsa
   ```

3. Copy public key to agents:
   ```bash
   # First, display the public key content
   sudo cat /var/lib/jenkins/.ssh/id_rsa.pub
   
   # SSH to each agent as ec2-user and manually add the key
   ssh -i your-key.pem ec2-user@<agent_ip>
   
   # On the agent, switch to jenkins user and add the public key
   sudo su - jenkins
   mkdir -p ~/.ssh
   chmod 700 ~/.ssh
   
   # Create authorized_keys file and paste the public key content
   vi ~/.ssh/authorized_keys
   # Paste the public key content from the master, then save and exit
   
   chmod 600 ~/.ssh/authorized_keys
   exit  # exit from jenkins user back to ec2-user
   ```

   **Alternative one-liner method:**
   ```bash
   # From Jenkins master, copy the key directly
   sudo cat /var/lib/jenkins/.ssh/id_rsa.pub | ssh -i your-key.pem ec2-user@<agent_ip> "sudo -u jenkins tee -a /home/jenkins/.ssh/authorized_keys && sudo -u jenkins chmod 600 /home/jenkins/.ssh/authorized_keys && sudo -u jenkins chmod 700 /home/jenkins/.ssh"
   ```

## 🐳 Salesforce & Node.js Pipeline Examples

### Basic Node.js Pipeline

```groovy
pipeline {
    agent {
        label 'nodejs'
    }
    stages {
        stage('Install Dependencies') {
            steps {
                sh 'npm install'
            }
        }
        stage('Run Tests') {
            steps {
                sh 'npm test'
            }
        }
        stage('Build') {
            steps {
                sh 'npm run build'
            }
        }
    }
}
```

### Salesforce CLI Pipeline

```groovy
pipeline {
    agent {
        label 'salesforce'
    }
    environment {
        SFDX_AUTOUPDATE_DISABLE = 'true'
        SFDX_USE_GENERIC_UNIX_KEYCHAIN = 'true'
        SFDX_DOMAIN_RETRY = '300'
    }
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        stage('Authorize Org') {
            steps {
                withCredentials([string(credentialsId: 'salesforce-url', variable: 'SF_AUTH_URL')]) {
                    sh 'echo $SF_AUTH_URL > authfile'
                    sh 'sf org login sfdx-url --sfdx-url-file authfile --alias DevOrg'
                    sh 'rm authfile'
                }
            }
        }
        stage('Run Tests') {
            steps {
                sh 'sf apex run test --target-org DevOrg --wait 10 --result-format human --code-coverage'
            }
        }
        stage('Deploy') {
            steps {
                sh 'sf project deploy start --target-org DevOrg --wait 10'
            }
        }
    }
}
```

### Docker-based Salesforce Pipeline

```groovy
pipeline {
    agent {
        label 'docker && salesforce'
    }
    stages {
        stage('Build with Salesforce DX') {
            steps {
                script {
                    docker.image('salesforce/salesforcedx:latest-full').inside {
                        sh 'sf --version'
                        sh 'sf project deploy validate --target-org DevOrg'
                    }
                }
            }
        }
    }
}
```

### Node.js + Salesforce Lightning Web Components

```groovy
pipeline {
    agent {
        label 'nodejs && salesforce'
    }
    stages {
        stage('Install Dependencies') {
            steps {
                sh 'npm install'
            }
        }
        stage('Lint LWC Components') {
            steps {
                sh 'npm run lint:lwc'
            }
        }
        stage('Test LWC Components') {
            steps {
                sh 'npm run test:unit'
            }
        }
        stage('Build and Deploy') {
            steps {
                withCredentials([string(credentialsId: 'salesforce-url', variable: 'SF_AUTH_URL')]) {
                    sh 'echo $SF_AUTH_URL > authfile'
                    sh 'sf org login sfdx-url --sfdx-url-file authfile --alias DevOrg'
                    sh 'sf project deploy start --target-org DevOrg --wait 10'
                    sh 'rm authfile'
                }
            }
        }
    }
}
```

## 🔧 Pre-installed Tools on Salesforce Agent

The agent comes with:
- **Node.js 18**: Latest LTS version with npm
- **Salesforce CLI (sf)**: Latest version for Salesforce development
- **Docker & Docker Compose**: Container runtime
- **Java 17**: Amazon Corretto JDK
- **AWS CLI v2**: AWS command line tools
- **Terraform**: Infrastructure as Code
- **kubectl**: Kubernetes management
- **Git**: Version control
- **Node.js Development Tools**:
  - yarn: Alternative package manager
  - TypeScript: TypeScript compiler
  - Angular CLI: Angular development
  - Create React App: React development
- **Docker Images**: node:18, node:18-alpine, salesforce/salesforcedx:latest-full, alpine, ubuntu

## 📊 Monitoring and Troubleshooting

### Check Agent Status

```bash
# SSH to agent
ssh -i your-key.pem ec2-user@<agent_ip>

# Check agent logs
sudo tail -f /var/log/jenkins-agent-bootstrap.log

# Check Docker status
sudo systemctl status docker

# Check if agent is ready
sudo systemctl status jenkins-agent-ready.service

# Test Salesforce CLI
sf --version

# Test Node.js tools
node --version
npm --version
```

### Common Issues

1. **Agent Won't Connect**:
   - Check security groups (port 22 open)
   - Verify SSH credentials
   - Check agent logs

2. **Docker Permission Issues**:
   - Ensure jenkins user is in docker group: `groups jenkins`
   - Restart agent if needed

3. **Out of Disk Space**:
   - Clean Docker images: `docker system prune -a`
   - Monitor disk usage: `df -h`

## 🚀 Advanced Configuration

### Auto-scaling Agents

Consider using Jenkins Kubernetes plugin or AWS ECS plugin for dynamic agent scaling.

### Docker-in-Docker (DinD)

For advanced Docker builds, you might need Docker-in-Docker:

```groovy
pipeline {
    agent {
        label 'docker'
    }
    stages {
        stage('Docker in Docker') {
            steps {
                script {
                    docker.image('docker:dind').withRun('--privileged') { c ->
                        docker.image('docker:latest').inside("--link ${c.id}:docker") {
                            sh 'docker version'
                        }
                    }
                }
            }
        }
    }
}
```

## 💰 Cost Optimization

- **Scheduled Agents**: Stop agents during non-business hours
- **Spot Instances**: Use spot instances for cost savings
- **Right-sizing**: Monitor resource usage and adjust instance types

---

**Note**: The agents are configured to automatically download common Docker images during bootstrap to speed up initial builds.

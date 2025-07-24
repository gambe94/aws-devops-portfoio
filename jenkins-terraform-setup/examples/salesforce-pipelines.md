# Salesforce Jenkins Pipeline Examples

This directory contains example Jenkins pipeline configurations for Salesforce development.

## 🚀 Quick Start

### 1. Create a New Salesforce Project

```bash
# On your local machine or in Jenkins
sf project generate --name my-salesforce-project
cd my-salesforce-project
```

### 2. Basic Jenkinsfile for Salesforce

Create a `Jenkinsfile` in your project root:

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
        
        stage('Authorize DevHub') {
            steps {
                withCredentials([string(credentialsId: 'devhub-auth-url', variable: 'DEVHUB_AUTH_URL')]) {
                    sh 'echo $DEVHUB_AUTH_URL > devhub_auth.txt'
                    sh 'sf org login sfdx-url --sfdx-url-file devhub_auth.txt --alias DevHub --set-default-dev-hub'
                    sh 'rm devhub_auth.txt'
                }
            }
        }
        
        stage('Create Scratch Org') {
            steps {
                sh 'sf org create scratch --definition-file config/project-scratch-def.json --alias TestOrg --set-default --duration-days 1'
            }
        }
        
        stage('Push Source') {
            steps {
                sh 'sf project deploy start --target-org TestOrg'
            }
        }
        
        stage('Run Tests') {
            steps {
                sh 'sf apex run test --target-org TestOrg --wait 10 --result-format human --code-coverage'
            }
        }
        
        stage('Delete Scratch Org') {
            steps {
                sh 'sf org delete scratch --target-org TestOrg --no-prompt'
            }
        }
    }
    
    post {
        always {
            // Clean up scratch org even if pipeline fails
            sh 'sf org delete scratch --target-org TestOrg --no-prompt || true'
        }
        success {
            echo 'Pipeline succeeded!'
        }
        failure {
            echo 'Pipeline failed!'
        }
    }
}
```

### 3. Lightning Web Components Pipeline

```groovy
pipeline {
    agent {
        label 'nodejs && salesforce'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Install Dependencies') {
            steps {
                sh 'npm install'
            }
        }
        
        stage('Lint') {
            steps {
                sh 'npm run lint'
            }
        }
        
        stage('Test LWC') {
            steps {
                sh 'npm run test:unit'
            }
        }
        
        stage('Build') {
            steps {
                sh 'npm run build'
            }
        }
        
        stage('Deploy to Org') {
            when {
                branch 'main'
            }
            steps {
                withCredentials([string(credentialsId: 'prod-org-auth', variable: 'ORG_AUTH_URL')]) {
                    sh 'echo $ORG_AUTH_URL > org_auth.txt'
                    sh 'sf org login sfdx-url --sfdx-url-file org_auth.txt --alias ProdOrg'
                    sh 'sf project deploy start --target-org ProdOrg --wait 10'
                    sh 'rm org_auth.txt'
                }
            }
        }
    }
}
```

### 4. Package Development Pipeline

```groovy
pipeline {
    agent {
        label 'salesforce'
    }
    
    environment {
        PACKAGE_NAME = 'MyAwesomePackage'
        SFDX_AUTOUPDATE_DISABLE = 'true'
    }
    
    stages {
        stage('Authorize DevHub') {
            steps {
                withCredentials([string(credentialsId: 'devhub-auth-url', variable: 'DEVHUB_AUTH_URL')]) {
                    sh 'echo $DEVHUB_AUTH_URL > devhub_auth.txt'
                    sh 'sf org login sfdx-url --sfdx-url-file devhub_auth.txt --alias DevHub --set-default-dev-hub'
                    sh 'rm devhub_auth.txt'
                }
            }
        }
        
        stage('Create Package Version') {
            steps {
                script {
                    def packageVersion = sh(
                        script: 'sf package version create --package $PACKAGE_NAME --wait 10 --json | jq -r .result.SubscriberPackageVersionId',
                        returnStdout: true
                    ).trim()
                    
                    env.PACKAGE_VERSION_ID = packageVersion
                    echo "Created package version: ${packageVersion}"
                }
            }
        }
        
        stage('Install in Test Org') {
            steps {
                sh 'sf org create scratch --definition-file config/project-scratch-def.json --alias PackageTestOrg --duration-days 1'
                sh 'sf package install --package $PACKAGE_VERSION_ID --target-org PackageTestOrg --wait 10'
            }
        }
        
        stage('Run Package Tests') {
            steps {
                sh 'sf apex run test --target-org PackageTestOrg --wait 10 --result-format human'
            }
        }
        
        stage('Promote Package') {
            when {
                branch 'main'
            }
            steps {
                sh 'sf package version promote --package $PACKAGE_VERSION_ID'
            }
        }
    }
    
    post {
        always {
            sh 'sf org delete scratch --target-org PackageTestOrg --no-prompt || true'
        }
    }
}
```

## 🔧 Setup Instructions

### 1. Configure Jenkins Credentials

In Jenkins, go to **Manage Jenkins** → **Manage Credentials** and add:

1. **DevHub Auth URL** (String):
   - ID: `devhub-auth-url`
   - Description: "DevHub SFDX Auth URL"
   - Secret: Your DevHub auth URL (get with `sf org display --verbose`)

2. **Production Org Auth URL** (String):
   - ID: `prod-org-auth`
   - Description: "Production Org Auth URL"
   - Secret: Your production org auth URL

### 2. Project Structure

Your Salesforce project should have:

```
my-salesforce-project/
├── Jenkinsfile
├── sfdx-project.json
├── config/
│   └── project-scratch-def.json
├── force-app/
│   └── main/
│       └── default/
│           ├── classes/
│           ├── lwc/
│           └── triggers/
├── package.json (for LWC projects)
└── .eslintrc.json (for LWC projects)
```

### 3. package.json for LWC Projects

```json
{
  "name": "my-salesforce-project",
  "version": "1.0.0",
  "scripts": {
    "lint": "eslint **/lwc/**/*.js",
    "test:unit": "lwc-jest",
    "test:unit:watch": "lwc-jest --watch",
    "test:unit:debug": "lwc-jest --debug",
    "build": "echo 'No build step required for LWC'"
  },
  "devDependencies": {
    "@lwc/eslint-plugin-lwc": "^1.0.0",
    "@salesforce/eslint-config-lwc": "^3.0.0",
    "@salesforce/eslint-plugin-aura": "^2.0.0",
    "@salesforce/lwc-jest": "^1.0.0",
    "eslint": "^8.0.0",
    "jest": "^29.0.0"
  }
}
```

### 4. Webhook Configuration

To trigger builds automatically:

1. In your Git repository (GitHub, GitLab, etc.), add a webhook:
   - URL: `http://<jenkins-ip>:8080/github-webhook/` (for GitHub)
   - Events: Push, Pull Request

2. In Jenkins job configuration:
   - Enable "GitHub hook trigger for GITScm polling"

## 🎯 Best Practices

1. **Use Scratch Orgs**: Always test in scratch orgs first
2. **Separate Pipelines**: Different pipelines for different environments
3. **Security**: Store auth URLs as Jenkins credentials, never in code
4. **Testing**: Always run tests before deployment
5. **Cleanup**: Always delete scratch orgs in post actions
6. **Versioning**: Use semantic versioning for packages

## 📊 Monitoring

Monitor your pipelines:
- Check build history in Jenkins
- Set up email notifications for failures
- Use Blue Ocean for better visualization
- Monitor Salesforce org limits during builds

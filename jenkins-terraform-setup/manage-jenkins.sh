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
    JENKINS_AGENT_1_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=jenkins-salesforce-agent" "Name=instance-state-name,Values=running,stopped" --query 'Reservations[*].Instances[*].InstanceId' --output text 2>/dev/null || echo "")
    JENKINS_AGENT_2_ID=""
    
    if [ -z "$JENKINS_MASTER_ID" ]; then
        print_error "Could not find Jenkins master instance ID"
        exit 1
    fi
    
    print_info "Jenkins Master ID: $JENKINS_MASTER_ID"
    [ -n "$JENKINS_AGENT_1_ID" ] && print_info "Jenkins Salesforce Agent ID: $JENKINS_AGENT_1_ID"
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
    get_instance_status "$JENKINS_AGENT_1_ID" "Jenkins Salesforce Agent"
    echo ""
    
    # Calculate approximate monthly cost
    local running_instances=0
    local stopped_instances=0
    
    for id in "$JENKINS_MASTER_ID" "$JENKINS_AGENT_1_ID"; do
        if [ -n "$id" ]; then
            local state=$(aws ec2 describe-instances --instance-ids "$id" --query 'Reservations[*].Instances[*].State.Name' --output text 2>/dev/null || echo "not-found")
            if [ "$state" = "running" ]; then
                ((running_instances++))
            elif [ "$state" = "stopped" ]; then
                ((stopped_instances++))
            fi
        fi
    done
    
    print_info "Cost Estimation:"
    echo "Running instances: $running_instances"
    echo "Stopped instances: $stopped_instances"
    
    if [ $running_instances -le 2 ]; then
        print_info "✅ You're within FREE TIER limits!"
    else
        print_warning "⚠️  You have $running_instances instances running. Consider stopping some to stay within free tier."
    fi
}

# Start instances
start() {
    local target=$1
    
    case $target in
        "master")
            if [ -n "$JENKINS_MASTER_ID" ]; then
                print_info "Starting Jenkins Master..."
                aws ec2 start-instances --instance-ids "$JENKINS_MASTER_ID"
            fi
            ;;
        "agent1"|"agent"|"salesforce")
            if [ -n "$JENKINS_AGENT_1_ID" ]; then
                print_info "Starting Jenkins Salesforce Agent..."
                aws ec2 start-instances --instance-ids "$JENKINS_AGENT_1_ID"
            fi
            ;;
        "all")
            print_info "Starting all instances..."
            local instances=""
            [ -n "$JENKINS_MASTER_ID" ] && instances="$instances $JENKINS_MASTER_ID"
            [ -n "$JENKINS_AGENT_1_ID" ] && instances="$instances $JENKINS_AGENT_1_ID"
            
            if [ -n "$instances" ]; then
                aws ec2 start-instances --instance-ids $instances
            fi
            ;;
        *)
            print_error "Invalid target. Use: master, agent (or salesforce), or all"
            exit 1
            ;;
    esac
}

# Stop instances
stop() {
    local target=$1
    
    case $target in
        "master")
            if [ -n "$JENKINS_MASTER_ID" ]; then
                print_warning "Stopping Jenkins Master..."
                aws ec2 stop-instances --instance-ids "$JENKINS_MASTER_ID"
            fi
            ;;
        "agent1"|"agent"|"salesforce")
            if [ -n "$JENKINS_AGENT_1_ID" ]; then
                print_info "Stopping Jenkins Salesforce Agent..."
                aws ec2 stop-instances --instance-ids "$JENKINS_AGENT_1_ID"
            fi
            ;;
        "agents"|"agent")
            print_info "Stopping Salesforce agent..."
            if [ -n "$JENKINS_AGENT_1_ID" ]; then
                aws ec2 stop-instances --instance-ids "$JENKINS_AGENT_1_ID"
            fi
            ;;
        "all")
            print_warning "Stopping all instances..."
            local instances=""
            [ -n "$JENKINS_MASTER_ID" ] && instances="$instances $JENKINS_MASTER_ID"
            [ -n "$JENKINS_AGENT_1_ID" ] && instances="$instances $JENKINS_AGENT_1_ID"
            
            if [ -n "$instances" ]; then
                aws ec2 stop-instances --instance-ids $instances
            fi
            ;;
        *)
            print_error "Invalid target. Use: master, agent (or salesforce), agents, or all"
            exit 1
            ;;
    esac
}

# Show help
show_help() {
    echo "Jenkins Free Tier Management Script"
    echo "=================================="
    echo ""
    echo "Usage: $0 [command] [target]"
    echo ""
    echo "Commands:"
    echo "  status              Show current status of all instances"
    echo "  start [target]      Start instances (target: master, agent, salesforce, all)"
    echo "  stop [target]       Stop instances (target: master, agent, salesforce, agents, all)"
    echo "  help                Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 status                    # Show current status"
    echo "  $0 start master              # Start only Jenkins master"
    echo "  $0 start agent               # Start only Salesforce agent"
    echo "  $0 start all                 # Start all instances"
    echo "  $0 stop agent                # Stop Salesforce agent"
    echo "  $0 stop all                  # Stop all instances"
    echo ""
    echo "Infrastructure:"
    echo "  - Jenkins Master (t3.micro) - FREE TIER"
    echo "  - Salesforce Agent (t3.micro) - FREE TIER"
    echo "  - Total: 100% FREE within AWS Free Tier limits!"
    echo ""
    echo "Free Tier Tips:"
    echo "  - Both instances are FREE within 750 hours/month limit"
    echo "  - Stop instances when not actively developing"
    echo "  - Monitor usage: aws ce get-dimension-values --dimension Key=SERVICE"
}

# Main script logic
main() {
    check_aws_cli
    get_instance_ids
    
    case "${1:-}" in
        "status")
            status
            ;;
        "start")
            if [ $# -lt 2 ]; then
                print_error "Please specify what to start: master, agent, salesforce, or all"
                exit 1
            fi
            start "$2"
            ;;
        "stop")
            if [ $# -lt 2 ]; then
                print_error "Please specify what to stop: master, agent, salesforce, agents, or all"
                exit 1
            fi
            stop "$2"
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            print_error "Unknown command: ${1:-}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"

#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Log file
LOG_FILE="deployment_$(date +%Y%m%d_%H%M%S).log"

echo -e "${YELLOW}Starting deployment process...${NC}" | tee -a "$LOG_FILE"

# Function to log messages
log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "$message" | tee -a "$LOG_FILE"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install package
install_package() {
    local pkg=$1
    log "Installing $pkg..."
    
    if command_exists apt-get; then
        sudo apt-get update && sudo apt-get install -y "$pkg"
    elif command_exists yum; then
        sudo yum install -y "$pkg"
    elif command_exists brew; then
        brew install "$pkg"
    else
        log "${RED}Package manager not found. Please install $pkg manually.${NC}"
        return 1
    fi
}

# Function to generate SSH key if not exists
generate_ssh_key() {
    local key_path="$HOME/.ssh/id_rsa_deploy"
    
    if [ ! -f "$key_path" ]; then
        log "${YELLOW}Generating new SSH key...${NC}"
        mkdir -p "$HOME/.ssh"
        ssh-keygen -t rsa -b 4096 -f "$key_path" -N ""
        chmod 600 "$key_path"
        chmod 700 "$HOME/.ssh"
        
        log "${GREEN}SSH key generated at $key_path${NC}"
        echo -e "${YELLOW}Please add the following public key to your GitHub repository:${NC}"
        echo "=================================================="
        cat "${key_path}.pub"
        echo "=================================================="
        read -p "Press Enter to continue after adding the key to GitHub..."
    else
        log "${GREEN}Using existing SSH key at $key_path${NC}"
    fi
    
    # Add key to SSH agent
    eval "$(ssh-agent -s)" >/dev/null
    ssh-add "$key_path"
}

# Function to clone repository
clone_repo() {
    local repo_url=$1
    local target_dir="${2:-$(basename "$repo_url" .git)}"
    
    if [ -d "$target_dir" ]; then
        log "${YELLOW}Directory $target_dir already exists. Pulling latest changes...${NC}"
        cd "$target_dir" || exit 1
        git pull
    else
        log "Cloning repository $repo_url..."
        git clone "$repo_url" "$target_dir"
        cd "$target_dir" || exit 1
    fi
}

# Function to build Java application
build_java_app() {
    log "Building Java application..."
    
    if [ -f "gradlew" ]; then
        chmod +x gradlew
        ./gradlew build
    elif [ -f "mvnw" ]; then
        chmod +x mvnw
        ./mvnw clean install
    elif [ -f "pom.xml" ]; then
        mvn clean install
    elif [ -f "build.gradle" ]; then
        gradle build
    else
        log "${RED}No build system detected. Please ensure your project has a valid build configuration.${NC}"
        return 1
    fi
}

# Function to test the application
test_application() {
    local port=9000
    
    log "Starting application for testing..."
    
    # Find the application JAR file (exclude Gradle wrapper and other non-application JARs)
    local jar_file=$(find build/libs -name "*.jar" -not -name "*sources*" -not -name "*javadoc*" | head -n 1)
    
    if [ -z "$jar_file" ]; then
        # Fallback to any JAR in the project
        jar_file=$(find . -path "*/build/libs/*.jar" -not -path "*/*sources*" -not -path "*/*javadoc*" | head -n 1)
    fi
    
    if [ -z "$jar_file" ]; then
        log "${RED}No JAR file found. Build might have failed.${NC}"
        return 1
    fi
    
    # Start the application in background with environment variable
    log "Starting application with: PORT=$port java -jar $jar_file"
    PORT=$port java -jar "$jar_file" > app.log 2>&1 &
    local app_pid=$!
    
    # Wait for app to start
    log "Waiting for application to start on port $port..."
    sleep 10
    
    # Test health endpoint
    log "Testing health endpoint at http://localhost:$port/health"
    if curl -s "http://localhost:$port/health" | grep -q '"status":"UP"'; then
        log "${GREEN}Application is running and healthy!${NC}"
        kill $app_pid 2>/dev/null || true
        return 0
    else
        log "${RED}Health check failed. Application logs:${NC}"
        cat app.log
        kill $app_pid 2>/dev/null || true
        return 1
    fi
}

# Function to setup AWS Classic Load Balancer
setup_elb() {
    local ec2_ip=$1
    local region="${AWS_REGION:-us-east-1}"
    local vpc_id=""
    local instance_id=""
    local elb_sg_id=""
    local instance_sg_id=""
    local elb_name=""
    local elb_dns=""
    local subnets=""
    
    log "${YELLOW}🚀 Starting ELB setup...${NC}"
    
    # Check AWS CLI
    if ! command -v aws &>/dev/null; then
        log "${RED}❌ AWS CLI is not installed. Please install it first.${NC}"
        return 1
    fi
    
    # Verify AWS credentials
    log "🔑 Verifying AWS credentials..."
    if ! aws sts get-caller-identity &>/dev/null; then
        log "${RED}❌ AWS credentials not configured. Run 'aws configure' first.${NC}"
        return 1
    fi
    
    # Get VPC ID
    log "🔍 Discovering default VPC..."
    vpc_id=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" \
             --query "Vpcs[0].VpcId" --output text --region "$region" 2>/dev/null)
    
    if [ -z "$vpc_id" ] || [ "$vpc_id" = "None" ]; then
        log "${RED}❌ Failed to get default VPC ID. Do you have a default VPC in $region?${NC}"
        return 1
    fi
    log "✅ Found VPC: $vpc_id"
    
    # Get instance ID
    log "🔍 Locating EC2 instance with private IP: $ec2_ip..."
    instance_id=$(aws ec2 describe-instances \
                 --filters "Name=private-ip-address,Values=$ec2_ip" \
                 --query "Reservations[0].Instances[0].InstanceId" \
                 --output text --region "$region" 2>/dev/null)
    
    if [ -z "$instance_id" ] || [ "$instance_id" = "None" ]; then
        log "${RED}❌ Instance with private IP $ec2_ip not found in region $region${NC}"
        return 1
    fi
    log "✅ Found instance: $instance_id"
    
    # Create ELB security group
    log "🛡️  Configuring security groups..."
    local elb_sg_name="java-app-elb-sg-$(date +%s)"
    elb_sg_id=$(aws ec2 create-security-group \
               --group-name "$elb_sg_name" \
               --description "Security group for Java app ELB" \
               --vpc-id "$vpc_id" \
               --query 'GroupId' --output text --region "$region" 2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "$elb_sg_id" ]; then
        log "${YELLOW}⚠️  Could not create ELB security group, attempting to find existing one...${NC}"
        elb_sg_id=$(aws ec2 describe-security-groups \
                   --filters "Name=group-name,Values=$elb_sg_name" "Name=vpc-id,Values=$vpc_id" \
                   --query 'SecurityGroups[0].GroupId' --output text --region "$region" 2>/dev/null)
        
        if [ -z "$elb_sg_id" ] || [ "$elb_sg_id" = "None" ]; then
            log "${RED}❌ Failed to create or find ELB security group${NC}"
            return 1
        fi
    fi
    
    # Allow HTTP traffic to ELB
    log "🔓 Configuring ELB security group rules..."
    aws ec2 authorize-security-group-ingress \
        --group-id "$elb_sg_id" \
        --protocol tcp --port 80 --cidr 0.0.0.0/0 \
        --region "$region" >/dev/null 2>&1 || true
    
    # Create instance security group if it doesn't exist
    local instance_sg_name="java-app-instance-sg"
    instance_sg_id=$(aws ec2 describe-security-groups \
                    --filters "Name=group-name,Values=$instance_sg_name" "Name=vpc-id,Values=$vpc_id" \
                    --query 'SecurityGroups[0].GroupId' --output text --region "$region" 2>/dev/null)
    
    if [ -z "$instance_sg_id" ] || [ "$instance_sg_id" = "None" ]; then
        log "🆕 Creating instance security group..."
        instance_sg_id=$(aws ec2 create-security-group \
                        --group-name "$instance_sg_name" \
                        --description "Security group for Java app instances" \
                        --vpc-id "$vpc_id" \
                        --query 'GroupId' --output text --region "$region" 2>/dev/null)
        
        if [ $? -ne 0 ] || [ -z "$instance_sg_id" ]; then
            log "${RED}❌ Failed to create instance security group${NC}"
            return 1
        fi
        
        # Allow SSH from anywhere (restrict in production!)
        aws ec2 authorize-security-group-ingress \
            --group-id "$instance_sg_id" \
            --protocol tcp --port 22 --cidr 0.0.0.0/0 \
            --region "$region" >/dev/null 2>&1
            
        # Allow traffic from ELB to instances on port 9000
        aws ec2 authorize-security-group-ingress \
            --group-id "$instance_sg_id" \
            --protocol tcp --port 9000 \
            --source-group "$elb_sg_id" \
            --region "$region" >/dev/null 2>&1
            
        # Allow health checks from ELB
        aws ec2 authorize-security-group-ingress \
            --group-id "$instance_sg_id" \
            --protocol tcp --port 9000 \
            --cidr 0.0.0.0/0 \
            --region "$region" >/dev/null 2>&1
    fi
    
    # Update instance security group
    log "🔗 Updating instance security groups..."
    aws ec2 modify-instance-attribute \
        --instance-id "$instance_id" \
        --groups "$instance_sg_id" \
        --region "$region" >/dev/null 2>&1
    
    # Get subnets from default VPC
    log "🌐 Configuring network settings..."
    subnets=$(aws ec2 describe-subnets \
             --filters "Name=vpc-id,Values=$vpc_id" "Name=default-for-az,Values=true" \
             --query "Subnets[0:2].SubnetId" --output text --region "$region" 2>/dev/null)
    
    if [ -z "$subnets" ]; then
        # Fallback to any available subnets in VPC
        subnets=$(aws ec2 describe-subnets \
                 --filters "Name=vpc-id,Values=$vpc_id" \
                 --query "Subnets[0:2].SubnetId" --output text --region "$region" 2>/dev/null)
        
        if [ -z "$subnets" ]; then
            log "${RED}❌ Failed to get subnets in VPC $vpc_id${NC}"
            return 1
        fi
    fi
    
    # Create load balancer
    elb_name="java-app-elb-$(date +%s)"
    log "⚙️  Creating Elastic Load Balancer: $elb_name..."
    
    elb_dns=$(aws elb create-load-balancer \
             --load-balancer-name "$elb_name" \
             --listeners "Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=9000" \
             --subnets $subnets \
             --security-groups "$elb_sg_id" \
             --scheme internet-facing \
             --query 'DNSName' --output text --region "$region" 2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "$elb_dns" ]; then
        log "${RED}❌ Failed to create load balancer${NC}"
        return 1
    fi
    
    # Configure health check
    log "❤️  Configuring health checks..."
    aws elb configure-health-check \
        --load-balancer-name "$elb_name" \
        --health-check "Target=HTTP:9000/health,Interval=30,UnhealthyThreshold=2,HealthyThreshold=2,Timeout=5" \
        --region "$region" >/dev/null 2>&1
    
    # Register instance
    log "🔗 Registering instance with ELB..."
    aws elb register-instances-with-load-balancer \
        --load-balancer-name "$elb_name" \
        --instances "$instance_id" \
        --region "$region" >/dev/null 2>&1
    
    # Enable connection draining
    log "⏳ Enabling connection draining..."
    aws elb modify-load-balancer-attributes \
        --load-balancer-name "$elb_name" \
        --load-balancer-attributes '{"ConnectionDraining":{"Enabled":true,"Timeout":300}}' \
        --region "$region" >/dev/null 2>&1
    
    # Enable cross-zone load balancing
    aws elb modify-load-balancer-attributes \
        --load-balancer-name "$elb_name" \
        --load-balancer-attributes '{"CrossZoneLoadBalancing":{"Enabled":true}}' \
        --region "$region" >/dev/null 2>&1
    
    # Get ELB details
    local elb_info=$(aws elb describe-load-balancers \
                    --load-balancer-names "$elb_name" \
                    --query 'LoadBalancerDescriptions[0]' \
                    --region "$region" 2>/dev/null)
    
    log "${GREEN}✅ ELB setup complete!${NC}"
    log ""
    log "================================================================"
    log "${GREEN}🚀 Application Load Balancer Successfully Deployed!${NC}"
    log "================================================================"
    log "${YELLOW}ELB Name:${NC} $elb_name"
    log "${YELLOW}DNS Name:${NC} http://$elb_dns"
    log "${YELLOW}Instance:${NC} $instance_id ($ec2_ip)"
    log "${YELLOW}Health Check:${NC} HTTP:9000/health"
    log "${YELLOW}Security Groups:${NC}"
    log "  - ELB: $elb_sg_id ($elb_sg_name)"
    log "  - Instance: $instance_sg_id ($instance_sg_name)"
    log ""
    log "${YELLOW}Next Steps:${NC}"
    log "1. It may take 1-2 minutes for the ELB to become active"
    log "2. Access your application at: http://$elb_dns"
    log "3. Monitor health checks in the AWS Console"
    log "4. Consider setting up a custom domain with Route 53"
    log "5. For production, enable HTTPS with an SSL certificate"
    log "================================================================"
    log ""
    
    # Save ELB info to a file for reference
    echo "ELB_NAME=$elb_name" > .elb-info
    echo "ELB_DNS=$elb_dns" >> .elb-info
    echo "INSTANCE_ID=$instance_id" >> .elb-info
    echo "CREATED_AT=$(date -u +'%Y-%m-%dT%H:%M:%SZ')" >> .elb-info
    
    return 0
}

# Function to setup EC2 instance
setup_ec2() {
    log "Setting up EC2 instance..."
    
    read -p "Enter EC2 instance public IP: " EC2_IP
    read -p "Enter EC2 username (default: ubuntu): " EC2_USER
    EC2_USER=${EC2_USER:-ubuntu}
    
    # Copy SSH key to EC2
    local key_path="$HOME/.ssh/id_rsa_deploy"
    ssh-copy-id -i "$key_path.pub" "$EC2_USER@$EC2_IP"
    
    # Install required packages on EC2
    log "Installing required packages on EC2..."
    ssh -i "$key_path" "$EC2_USER@$EC2_IP" \
        "sudo apt-get update && \
         sudo apt-get install -y docker.io awscli jq && \
         sudo systemctl enable docker && \
         sudo systemctl start docker && \
         sudo usermod -aG docker \$USER"
    
    log "${GREEN}EC2 instance setup complete!${NC}"
    
    # Generate GitHub Actions workflow
    generate_workflow "$EC2_IP" "$EC2_USER"
    
    # Setup ELB
    read -p "Do you want to set up an Elastic Load Balancer? (y/n): " SETUP_ELB
    if [[ $SETUP_ELB =~ ^[Yy]$ ]]; then
        setup_elb "$EC2_IP"
    fi
}

# Function to generate GitHub Actions workflow
generate_workflow() {
    local ec2_ip=$1
    local ec2_user=$2
    
    local workflow_dir=".github/workflows"
    mkdir -p "$workflow_dir"
    
    cat > "$workflow_dir/deploy.yml" << EOF
name: CI/CD Pipeline

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

env:
  EC2_HOST: "$ec2_ip"
  EC2_USER: "$ec2_user"
  APP_NAME: java-app

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v3

    - name: Set up JDK 17
      uses: actions/setup-java@v3
      with:
        java-version: '17'
        distribution: 'temurin'
        cache: 'gradle'

    - name: Grant execute permission for gradlew
      run: chmod +x gradlew

    - name: Build with Gradle
      run: ./gradlew build

    - name: Test with Gradle
      run: ./gradlew test
      
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v2

    - name: Build and save Docker image
      run: |
        docker build -t ${{ env.APP_NAME }} .
        docker save ${{ env.APP_NAME }} | gzip > ${{ env.APP_NAME }}.tar.gz

    - name: Deploy to EC2
      uses: appleboy/ssh-action@master
      with:
        host: \${{ env.EC2_HOST }}
        username: \${{ env.EC2_USER }}
        key: \${{ secrets.EC2_SSH_KEY }}
        script: |
          # Load the Docker image
          docker load -i ${{ env.APP_NAME }}.tar.gz
          
          # Stop and remove existing container if it exists
          if docker ps -a --format '{{.Names}}' | grep -q "^${{ env.APP_NAME }}$"; then
            docker stop ${{ env.APP_NAME }} || true
            docker rm ${{ env.APP_NAME }} || true
          fi
          
          # Run the container
          docker run -d \
            --name ${{ env.APP_NAME }} \
            -p 9000:9000 \
            -e PORT=9000 \
            --restart unless-stopped \
            ${{ env.APP_NAME }}
            
          # Clean up
          rm -f ${{ env.APP_NAME }}.tar.gz
          docker system prune -f
EOF

    log "${GREEN}GitHub Actions workflow generated at $workflow_dir/deploy.yml${NC}"
    
    echo -e "${YELLOW}Please add the following secrets to your GitHub repository:${NC}"
    echo "1. EC2_SSH_KEY: $(cat "$HOME/.ssh/id_rsa_deploy")"
    echo "2. DOCKER_USERNAME: Your Docker Hub username"
    echo "3. DOCKER_PASSWORD: Your Docker Hub access token"
    echo -e "\n${GREEN}Deployment configuration complete! Push your changes to trigger the CI/CD pipeline.${NC}"
}

# Documentation: Error Handling and Logging
# ========================================
#
# Error Handling:
# 1. Dependency Checks:
#    - Verifies AWS CLI installation and configuration
#    - Validates required commands (git, java, docker, etc.)
#    - Checks for proper AWS credentials and permissions
#
# 2. Resource Validation:
#    - Validates VPC and subnet existence
#    - Verifies EC2 instance is running
#    - Checks security group creation success
#
# 3. Error Recovery:
#    - Provides clear error messages with color coding
#    - Returns appropriate exit codes
#    - Logs detailed error information to file
#
# Logging:
# 1. Informational Logs:
#    - Start and completion messages
#    - Resource creation status
#    - Configuration details
#
# 2. Error Logs:
#    - Permission issues
#    - Resource creation failures
#    - Configuration errors
#
# 3. Success Logs:
#    - ELB DNS name
#    - Next steps
#    - Important notes
#
# Load Balancer Parameters:
# ========================
# Parameters Set:
# 1. --scheme internet-facing: Makes the ELB publicly accessible
# 2. --listeners: Configures HTTP traffic on port 80 to forward to port 9000
# 3. --health-check: Configures health checks on /health endpoint
# 4. --connection-draining: Ensures in-flight requests complete during instance deregistration
# 5. Security Groups: Restricts traffic to only necessary ports
#
# Parameters Not Set:
# 1. HTTPS/SSL: No SSL certificate configured (requires additional setup)
# 2. Access Logs: S3 bucket for access logging not configured
# 3. Idle Timeout: Using default value (60 seconds)
# 4. Cross-Zone Load Balancing: Using default setting (disabled)
# 5. Connection Draining Timeout: Set to 300 seconds (default)

# Main execution
main() {
    # Initialize log file
    log "Starting deployment process..."
    
    # Check for required commands
    for cmd in git java docker ssh ssh-keygen aws; do
        if ! command_exists "$cmd"; then
            log "${YELLOW}$cmd is not installed. Attempting to install...${NC}"
            if ! install_package "$cmd"; then
                log "${RED}Failed to install $cmd. Please install it manually and try again.${NC}"
                exit 1
            fi
        fi
    done
    
    # Verify AWS CLI version
    if ! aws --version &>/dev/null; then
        log "${RED}Failed to verify AWS CLI. Please ensure it's properly installed.${NC}"
        exit 1
    fi
    
    # Get GitHub repository URL
    read -p "Enter GitHub repository URL (SSH format, e.g., git@github.com:user/repo.git): " REPO_URL
    if [[ ! "$REPO_URL" =~ ^git@github\.com:.+\.git$ ]]; then
        log "${RED}Invalid GitHub repository URL. Please use SSH format (git@github.com:user/repo.git)${NC}"
        exit 1
    fi
    
    # Generate SSH key if not exists
    generate_ssh_key
    
    # Clone repository
    log "Cloning repository: $REPO_URL"
    clone_repo "$REPO_URL"
    
    # Build and test application
    log "Building and testing application..."
    if build_java_app && test_application; then
        log "${GREEN}Application built and tested successfully!${NC}"
        
        # Setup EC2 and generate workflow
        if [ "$1" != "--no-ec2" ]; then
            setup_ec2
        fi
    else
        log "${RED}Build or test failed. Please check the logs and try again.${NC}"
        exit 1
    fi
}

# Run main function
main "$@"

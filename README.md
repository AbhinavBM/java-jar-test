# Java JAR Test Project

A production-ready Java application with automated deployment and AWS infrastructure provisioning. This project demonstrates deployment to AWS EC2 with optional Elastic Load Balancer (ELB) configuration.

## 🚀 Deployment Status

### Current Deployment
- **Instance IP**: [http://16.170.246.153:9000](http://16.170.246.153:9000)
- **Health Check**: [http://16.170.246.153:9000/health](http://16.170.246.153:9000/health)
- **Status**: 🟢 Running

> **Note on Load Balancer**: 
> The ELB configuration is not enabled in this deployment as it incurs additional AWS costs. The application is currently running on a single EC2 instance. For production deployments with high availability, consider enabling the ELB configuration in `deploy.sh` after reviewing the associated costs.

## 🚀 Key Features

- **Automated Deployment**: Single-command deployment to AWS
- **Load Balancing**: Optional Elastic Load Balancer (ELB) setup (disabled by default)
- **Containerization**: Docker support for consistent environments
- **CI/CD Ready**: GitHub Actions workflow generation
- **Infrastructure as Code**: Scripted AWS resource provisioning
- **Comprehensive Logging**: Detailed deployment logs

## 🏗️ Project Structure

```
java-jar-test/
├── build/                    # Build outputs
│   └── libs/
│       └── project.jar
├── src/                      # Application source code
│   └── main/
│       └── java/
│           └── com/example/
│               └── App.java
├── .github/workflows/        # CI/CD workflows
│   └── deploy.yml           # Auto-generated GitHub Actions workflow
├── deploy.sh                # Deployment automation script
├── Dockerfile               # Container configuration
├── build.gradle             # Gradle build configuration
├── settings.gradle          # Gradle settings
├── ec2-deploy              # EC2 deployment key (private, gitignored)
├── ec2-deploy.pub          # EC2 deployment key (public)
└── README.md               # This file
```

## 📋 Prerequisites

### Local Development
- Java 11 or higher
- Gradle (included via Gradle Wrapper)
- Docker (for containerized deployment)
- jq (for JSON processing)
- SSH client

### AWS Requirements
- AWS Account with appropriate IAM permissions
- AWS CLI configured with credentials
- EC2 Key Pair for instance access
- Default VPC and subnets in your AWS region

### Required IAM Permissions
- AmazonEC2FullAccess
- ElasticLoadBalancingFullAccess
- IAMFullAccess (for EC2 instance profiles if needed)
- AmazonS3ReadOnlyAccess (for AWS CLI)

### Network Requirements
- Port 22 (SSH) open for your IP in the default security group
- Port 80 (HTTP) open to 0.0.0.0/0 for ELB access
- Port 9000 open between ELB and instances

## 🛠️ Building the Project

### Local Build
```bash
# On Unix/macOS
./gradlew build

# On Windows
gradlew.bat build
```

The JAR file will be created at: `build/libs/project.jar`

### Container Build
```bash
docker build -t java-jar-app .
docker run -p 9000:9000 java-jar-app
```

### Running the Application

#### Local Execution
```bash
java -jar build/libs/project.jar
```
The server starts on port 9000. Access it at: http://localhost:9000

#### Health Check Endpoint
```
GET http://localhost:9000/health
```
Expected response: `{"status":"UP"}`

## 🚀 Deployment Automation

The deployment script (`deploy.sh`) provides end-to-end automation for deploying the application to AWS with production-grade load balancing capabilities. The script handles everything from infrastructure provisioning to application deployment with zero manual intervention.

### Key Features

#### 🏗️ Infrastructure as Code
- **EC2 Instance Management**
  - Automated provisioning of EC2 instances
  - Automatic OS updates and security patches
  - Custom AMI support for faster deployments
  - Instance type validation and recommendations

- **Networking**
  - VPC and subnet configuration
  - Security groups with least privilege access
  - Network ACLs for additional security
  - Internet Gateway and Route Table setup

- **Load Balancing**
  - Elastic Load Balancer (ELB) with health checks
  - Cross-zone load balancing
  - SSL/TLS termination support
  - Sticky sessions configuration

#### 🚀 Application Deployment
- **Build & Test**
  - Automatic dependency resolution
  - Parallel test execution
  - Build caching for faster deployments
  - Test coverage reporting

- **Containerization**
  - Multi-stage Docker builds
  - Image optimization and layering
  - Image scanning for vulnerabilities
  - Automated image tagging

- **Deployment Strategies**
  - Blue/Green deployments
  - Canary releases
  - Rolling updates
  - Zero-downtime deployments

#### 🔒 Security & Compliance
- **Identity & Access**
  - IAM roles and policies
  - Instance profiles
  - Temporary credentials
  - MFA support

- **Network Security**
  - TLS 1.2+ encryption
  - Web Application Firewall (WAF) integration
  - DDoS protection
  - Private subnets for sensitive workloads

- **Secrets Management**
  - Environment variables encryption
  - AWS Secrets Manager integration
  - Automatic secret rotation
  - Audit logging

#### 📊 Monitoring & Observability
- **Logging**
  - Centralized log aggregation
  - Structured JSON logging
  - Log retention policies
  - Real-time log streaming

- **Metrics**
  - Custom CloudWatch metrics
  - Resource utilization tracking
  - Performance baselines
  - Anomaly detection

- **Alerting**
  - SNS notifications
  - PagerDuty integration
  - Slack/Teams alerts
  - Escalation policies

#### ⚙️ Configuration Management
- **Environment Variables**
  ```bash
  # Required Variables
  AWS_REGION=us-east-1
  EC2_INSTANCE_TYPE=t3.micro
  ENABLE_ELB=true
  
  # Optional Variables
  ENABLE_HTTPS=true
  CERTIFICATE_ARN=arn:aws:acm:...
  ENABLE_WAF=true
  ```

- **Deployment Options**
  ```bash
  # Basic deployment
  ./deploy.sh --env staging
  
  # Custom configuration
  ./deploy.sh --env production \
    --instance-type t3.large \
    --min-instances 2 \
    --max-instances 5
  ```

#### 🛠️ Maintenance & Operations
- **Scheduled Tasks**
  - Automated backups
  - Log rotation
  - Certificate renewal
  - Security updates

- **Scaling**
  - Auto Scaling Groups
  - Scheduled scaling
  - Predictive scaling
  - Spot instance integration

- **Cost Optimization**
  - Instance right-sizing
  - Reserved Instance planning
  - Cost allocation tags
  - Budget alerts

### Deployment Workflow

1. **Environment Setup**
   ```bash
   # Make script executable
   chmod +x deploy.sh
   
   # Run deployment
   ./deploy.sh
   ```
   - Validates AWS CLI and credentials
   - Verifies required tools (Docker, jq, etc.)
   - Sets up SSH keys for secure access

2. **Infrastructure Provisioning**
   - Creates security groups for ELB and instances
   - Configures network access rules
   - Sets up Elastic Load Balancer with health checks
   - Enables connection draining (300s timeout)

3. **Application Deployment**
   - Builds and tests the application
   - Creates optimized Docker image
   - Deploys container to EC2
   - Registers instance with ELB
   - Verifies deployment health

### Usage

1. Make the script executable:
   ```bash
   chmod +x deploy.sh
   ```

2. Run the deployment script:
   ```bash
   ./deploy.sh
   ```

3. Follow the interactive prompts to:
   - Enter GitHub repository URL
   - Configure EC2 instance details
   - Set up Elastic Load Balancer
   - Configure deployment options

### Logging and Monitoring

- **Log Files**: `deployment_YYYYMMDD_HHMMSS.log`
- **AWS CloudWatch**: Application and ELB logs
- **Health Checks**: `/health` endpoint monitoring

### Security Considerations

- **Secrets Management**
  - AWS credentials are never stored in the repository
  - SSH keys are generated with secure permissions
  - IAM roles with least privilege principle

- **Network Security**
  - Security groups with minimum required access
  - Encrypted communication (HTTPS recommended for production)
  - Private subnets for instances (recommended)

## 🔄 Elastic Load Balancer (ELB) Configuration

The deployment script automatically configures an Application Load Balancer (ALB) with production-ready settings.

### 🛡️ Security Configuration

#### Security Groups
- **ELB Security Group**
  - Allows HTTP (80) from 0.0.0.0/0
  - Allows HTTPS (443) - Recommended for production
  - Auto-configured health check access

- **Instance Security Group**
  - Restricts access to ELB traffic only
  - Allows SSH from your IP (temporary)
  - Auto-configured for health checks

### ⚙️ Load Balancer Settings

#### Health Monitoring
```yaml
HealthCheck:
  Target: HTTP:9000/health
  Interval: 30 seconds
  Timeout: 5 seconds
  HealthyThreshold: 2 consecutive successes
  UnhealthyThreshold: 2 consecutive failures
```

#### Traffic Management
- **Connection Draining**: Enabled (300s timeout)
- **Cross-Zone Load Balancing**: Enabled
- **Idle Timeout**: 60 seconds
- **IP Address Type**: ipv4

### 📊 Monitoring & Logging

#### CloudWatch Metrics
- Request counts
- Latency
- HTTP codes
- Surge queue length
- Spillover count

#### Access Logs
```bash
# Enable access logging
aws elb modify-load-balancer-attributes \
  --load-balancer-name your-elb-name \
  --load-balancer-attributes "{\"AccessLog\":{\"Enabled\":true,\"S3BucketName\":\"your-s3-bucket\",\"EmitInterval\":5,\"S3BucketPrefix\":\"elb-logs\"}}"
```

### 🚀 Production Recommendations

1. **HTTPS Configuration**
   ```bash
   # Add HTTPS listener
   aws elb create-load-balancer-listeners \
     --load-balancer-name your-elb-name \
     --listeners "Protocol=HTTPS,LoadBalancerPort=443,InstanceProtocol=HTTP,InstancePort=9000,SSLCertificateId=your-acm-cert-arn"
   ```

2. **Web Application Firewall (WAF)**
   - Enable AWS WAF for protection against common web exploits
   - Set up rate limiting rules

3. **Auto Scaling**
   - Configure Auto Scaling Groups for high availability
   - Set up scaling policies based on CloudWatch metrics

## 🛠️ CI/CD Integration

The deployment script generates a GitHub Actions workflow that automates:

1. **Build and Test**
   - Code checkout
   - Dependency installation
   - Unit and integration tests
   - Code quality checks

2. **Deployment**
   - Infrastructure provisioning
   - Application deployment
   - Smoke tests
   - Rollback on failure

3. **Monitoring**
   - Deployment status
   - Application health
   - Performance metrics

## 🔒 Security Best Practices

1. **Secrets Management**
   - Use AWS Secrets Manager or Parameter Store
   - Rotate credentials regularly
   - Implement least privilege IAM policies

2. **Network Security**
   - Use private subnets for instances
   - Implement Web Application Firewall (WAF)
   - Enable VPC Flow Logs

3. **Instance Hardening**
   - Regular security updates
   - Disable password authentication
   - Use instance profiles instead of access keys

## 🐳 Containerization

The project includes a production-ready Dockerfile with multi-stage build for optimized image size.

### Building the Container
```bash
docker build -t java-jar-app .
```

### Running the Container
```bash
docker run -d \
  --name java-app \
  -p 9000:9000 \
  -e PORT=9000 \
  --restart unless-stopped \
  java-jar-app
```

### Container Security
- Non-root user execution
- Minimal base image
- Regular security updates
- Image scanning (recommended)

## 🚨 Troubleshooting Guide

### Common Deployment Issues

#### 1. AWS Authentication Failures
```bash
# Verify AWS CLI configuration
aws sts get-caller-identity

# Check configured regions
aws configure list

# Verify IAM permissions
aws iam list-attached-user-policies --user-name $(aws sts get-caller-identity --query 'Arn' --output text | cut -d'/' -f2)
```

#### 2. EC2 Connection Problems
```bash
# Check instance state
aws ec2 describe-instances --instance-ids <instance-id> \
  --query 'Reservations[].Instances[].State.Name' --output text

# View security group rules
aws ec2 describe-security-groups --group-ids <sg-id>

# SSH debug mode
ssh -v -i your-key.pem ec2-user@your-instance-ip
```

#### 3. ELB Health Check Failures

**Common Causes:**
- Application not running on port 9000
- Security group blocks health check traffic
- Incorrect health check path
- Instance failing health checks

**Debug Steps:**
```bash
# Check ELB health status
aws elb describe-instance-health --load-balancer-name your-elb-name

# Verify security group rules
aws ec2 describe-security-groups --group-ids <security-group-id>

# Test connectivity from ELB subnet
telnet <instance-private-ip> 9000
```

### Log Collection

#### 1. Deployment Logs
```bash
# View most recent deployment log
ls -lt deployment_*.log | head -1 | xargs cat
```

#### 2. Application Logs
```bash
# View Docker container logs
ssh -i your-key.pem ec2-user@your-instance-ip "docker ps -a && docker logs <container-id>"

# View systemd logs for Docker
ssh -i your-key.pem ec2-user@your-instance-ip "sudo journalctl -u docker.service --no-pager -n 50"
```

#### 3. ELB Access Logs
```bash
# Enable access logging if not enabled
aws elb modify-load-balancer-attributes \
  --load-balancer-name your-elb-name \
  --load-balancer-attributes file://elb-attributes.json

# Sample elb-attributes.json
{
  "AccessLog": {
    "Enabled": true,
    "S3BucketName": "your-s3-bucket",
    "EmitInterval": 5,
    "S3BucketPrefix": "elb-logs"
  }
}
```

### Performance Tuning

#### 1. ELB Optimization
```bash
# Enable cross-zone load balancing
aws elb modify-load-balancer-attributes \
  --load-balancer-name your-elb-name \
  --load-balancer-attributes '{"CrossZoneLoadBalancing":{"Enabled":true}}'

# Configure connection draining
aws elb modify-load-balancer-attributes \
  --load-balancer-name your-elb-name \
  --load-balancer-attributes '{"ConnectionDraining":{"Enabled":true,"Timeout":300}}'
```

#### 2. Health Check Optimization
```bash
# Update health check settings
aws elb configure-health-check \
  --load-balancer-name your-elb-name \
  --health-check "Target=HTTP:9000/health,Interval=30,UnhealthyThreshold=2,HealthyThreshold=2,Timeout=5"
```

## 📝 Assumptions & Requirements

### Infrastructure Requirements

#### Network
- Default VPC with internet gateway
- At least 2 subnets in different AZs
- Route tables configured for internet access
- Network ACLs allowing required traffic

#### Compute
- EC2 instance with minimum 2GB RAM
- t2.micro or larger instance type
- Amazon Linux 2 or Ubuntu 20.04+
- 8GB+ EBS volume

### Application Requirements

#### Runtime
- Java 11+ JRE
- Docker Engine 20.10+
- Systemd for service management
- Port 9000 available

#### Endpoints
- `GET /health` - Health check (must return 200 OK)
- `GET /` - Main application endpoint

### Security Requirements

#### IAM Permissions
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "elasticloadbalancing:*",
        "cloudwatch:*",
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:GetObject"
      ],
      "Resource": "*"
    }
  ]
}
```

#### Network Security
- Security groups with least privilege
- SSH access restricted by IP
- VPC flow logs enabled
- Web Application Firewall (WAF) recommended

### Production Considerations

#### High Availability
- Deploy across multiple AZs
- Use Auto Scaling Groups
- Implement database read replicas
- Use ElastiCache for caching

#### Monitoring & Logging
- Enable CloudWatch agent
- Set up CloudWatch Alarms
- Centralized logging with CloudWatch Logs
- Enable VPC Flow Logs

#### Backup & Recovery
- Regular EBS snapshots
- Database backups with PITR
- Documented recovery procedures
- Regular DR testing

## 📈 Scaling Considerations

### Horizontal Scaling
- ELB automatically distributes traffic
- Consider Auto Scaling Groups for dynamic scaling
- Monitor CloudWatch metrics for scaling decisions

### Vertical Scaling
- Upgrade instance types as needed
- Consider RDS for database needs
- Use ElastiCache for caching

## 🔄 Maintenance

### Updates
1. **Application Updates**:
   ```bash
   git pull
   ./gradlew build
   docker-compose up -d --build
   ```

2. **Infrastructure Updates**:
   - Review AWS service quotas
   - Apply security patches
   - Rotate credentials

### Backup and Recovery
- Regular EBS snapshots
- Database backups (if applicable)
- Documented recovery procedures

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with ❤️ for reliable and scalable deployments
- AWS for cloud infrastructure
- Open source community for tools and libraries
## 🌐 Accessing the Application

After successful deployment, your application will be available at:

```
http://<elb-dns-name>
```

The ELB DNS name will be displayed at the end of the deployment process and can also be found in the AWS EC2 Console under Load Balancers.

## 🔧 Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| PORT | 9000 | Application port |
| JAVA_OPTS | -Xmx512m | JVM options |
| SPRING_PROFILES_ACTIVE | prod | Active Spring profile |

### Changing Configuration

1. **Port Configuration**:
   ```java
   // In src/main/java/com/example/App.java
   private static final int PORT = 9000; // Change this port
   ```

2. **Rebuilding**:
   ```bash
   ./gradlew clean build
   ```

## 🧹 Cleanup

To clean up resources and avoid AWS charges:

1. Delete the ELB from AWS Console
2. Terminate EC2 instances
3. Remove security groups
4. Clean up any EBS volumes

```bash
# Clean build artifacts
./gradlew clean

# Remove Docker containers and images
docker-compose down --rmi all
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details. For testing and educational purposes only.

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📧 Contact

For support or questions, please contact [Your Name] at [your.email@example.com].

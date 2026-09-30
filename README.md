# Production-Grade, Multi-AZ Auto-Healing AWS Web Platform

An automated, highly available, and resilient web infrastructure provisioned on AWS using **Terraform (Infrastructure as Code)**. This platform features zero-downtime auto-healing capabilities, Multi-AZ database replication, secure credentials management, and CloudWatch operational observability.

## 📐 Architecture Overview

The infrastructure is provisioned in **`us-east-1` (N. Virginia)** across two distinct Availability Zones (`us-east-1a` and `us-east-1b`) to guarantee fault tolerance and high availability.

```
                   +-------------------------------------------------------+
                   |                 Internet Gateway                      |
                   +---------------------------+---------------------------+
                                               |
                                    +----------v----------+
                                    |  Application Load   |
                                    |    Balancer (ALB)   |
                                    +----------+----------+
                                               |
                +------------------------------+------------------------------+
                |                                                             |
     +----------v----------+                                       +----------v----------+
     |  Public Subnet 1    |                                       |  Public Subnet 2    |
     |   (us-east-1a)      |                                       |   (us-east-1b)      |
     |                     |                                       |                     |
     |  [NAT Gateway 1]    |                                       |  [NAT Gateway 2]    |
     +----------+----------+                                       +----------+----------+
                |                                                             |
     +----------v----------+                                       +----------v----------+
     | Private App Subnet 1|                                       | Private App Subnet 2|
     |   (us-east-1a)      |                                       |   (us-east-1b)      |
     |                     |                                       |                     |
     |  [EC2 Web Server 1] | <========== Auto Scaling Group =========> |  [EC2 Web Server 2] |
     +----------+----------+                                       +----------+----------+
                |                                                             |
     +----------v----------+                                       +----------v----------+
     | Private DB Subnet 1 |                                       | Private DB Subnet 2 |
     |   (us-east-1a)      |                                       |   (us-east-1b)      |
     |                     |                                       |                     |
     |  [RDS Primary MySQL]| <====== Multi-AZ Synchronous Replication =====> [RDS Standby DB]   |
     +---------------------+                                       +---------------------+
```

### Key Architectural Components

1. **Networking & Isolation (VPC)**:
   * Dedicated VPC (`10.0.0.0/16`) split across 2 Availability Zones.
   * **6 Subnets total**: 2 Public, 2 Private Application, and 2 Private Database subnets.
   * Dual **NAT Gateways** in public subnets allowing private EC2 nodes secure outbound internet access for package updates (`dnf update`, `httpd`).

2. **Compute & Load Balancing**:
   * **Application Load Balancer (ALB)** deployed in public subnets distributing incoming HTTP traffic on port 80.
   * **Auto Scaling Group (ASG)** spanning private app subnets with a minimum/desired capacity of 2 instances and a maximum of 4 instances.
   * **Target Group (`ha-web-tg`)**: Configured with strict health checks targeting `/` to route traffic only to healthy targets.

3. **Database (RDS)**:
   * **Multi-AZ Amazon RDS (MySQL)** running in isolated private database subnets with automated failover support.
   * Database credentials automatically generated and stored in **AWS Secrets Manager** (encrypted at rest via KMS).

4. **Observability & Alerts**:
   * **CloudWatch Dashboard**: Real-time tracking of EC2 CPU utilization, ALB target response time, total HTTP request count, and healthy host count.
   * **SNS Alarms**: Email notification triggers when unhealthy host counts exceed thresholds or target response times degrade.

## 🛠️ Project File Structure

```
aws-ha-platform/
├── main.tf          # Provider setup, backend configurations, and global resources
├── vpc.tf           # VPC, Subnets, Internet/NAT Gateways, and Route Tables
├── compute.tf       # ALB, Target Group, Launch Template, and Auto Scaling Group
├── database.tf      # Multi-AZ RDS instance, DB Subnet Groups, and Secrets Manager
├── observability.tf # CloudWatch Dashboard, Alarms, and SNS Topic Subscriptions
├── variables.tf     # Configurable input variables (region, CIDR blocks, DB name)
├── outputs.tf       # Infrastructure outputs (ALB DNS URL, RDS Endpoint, ASG Name)
└── README.md        # Comprehensive project documentation
```

## 🚀 Prerequisites & Deployment Guide

### Prerequisites

* [AWS CLI v2](https://aws.amazon.com/cli/) installed and configured (`aws configure`).
* [Terraform CLI](https://developer.hashicorp.com/terraform/downloads) ($\ge$ v1.5.0) installed.
* Appropriate AWS IAM permissions for VPC, EC2, ALB, RDS, CloudWatch, and Secrets Manager creation.

### Step 1: Clone Repository & Open Folder

```bash
git clone https://github.com/YOUR-USERNAME/aws-ha-platform.git
cd aws-ha-platform
```

### Step 2: Initialize Terraform

Download required provider plugins (AWS Provider):

```bash
terraform init
```

### Step 3: Review Execution Plan

Validate syntax and preview the 20+ AWS resources to be provisioned:

```bash
terraform plan
```

### Step 4: Provision Infrastructure

Deploy the platform into `us-east-1`:

```bash
terraform apply
```

*Type `yes` when prompted. Provisioning takes ~6–8 minutes due to Multi-AZ RDS initialization.*

## 🧪 Verification & Demonstration Procedures

### 1. Web Traffic Verification

After `terraform apply` finishes, copy the `alb_dns_name` output:

```bash
terraform output alb_dns_name
```

Open `http://<YOUR-ALB-DNS-NAME>` in a web browser. You will see the Apache landing page hosted from the private EC2 application nodes.

### 2. Check Target Group Health

Execute via AWS CLI or check in the console:

```bash
aws elbv2 describe-target-health \
  --region us-east-1 \
  --target-group-arn $(aws elbv2 describe-target-groups --region us-east-1 --names "ha-web-tg" --query "TargetGroups[0].TargetGroupArn" --output text) \
  --query "TargetHealthDescriptions[*].[Target.Id, TargetHealth.State]" \
  --output table
```

*Expected Output: Both registered instance targets display as `healthy`.*

### 3. Fault Tolerance & Auto-Healing Test

To demonstrate zero-downtime high availability and automatic recovery:

1. Terminate one active web instance via the CLI:
   ```bash
   aws ec2 terminate-instances --region us-east-1 --instance-ids <INSTANCE_ID>
   ```
2. **Refresh the ALB DNS URL** in your browser immediately. Notice that website requests succeed without interruption because the load balancer routes traffic to the surviving AZ instance.
3. Observe the Auto Scaling Group in the AWS Console. Within 60–90 seconds, ASG detects the missing node and automatically provisions a replacement node to restore total capacity to 2.

## 🧹 Infrastructure Teardown

To avoid incurring ongoing charges for NAT Gateways, Multi-AZ RDS instances, and Load Balancers on your AWS account, tear down all resources when finished:

```bash
terraform destroy
```

*Type `yes` when prompted. Terraform will cleanly delete all created infrastructure in reverse dependency order.*
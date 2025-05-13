
# Defines region AWS would be deployed
variable "aws_region" {
  description = "AWS Region to deploy resources"
  type        = string
  default     = "us-east-1"
}

# Defines the IP range for the VPC (Virtual Private Cloud)
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16" # Change if your network needs a different range
}

# Defines the IP ranges for the public Subnet
variable "public_subnet_cidr" {
  description = "CIDR blocks for the Public Subnet"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.3.0/24"]

  validation {
    condition     = length(var.public_subnet_cidr) > 0
    error_message = "You must provide at least one CIDR block for public subnets."
  }
}


# Defines the IP Range for the private subnet
variable "private_subnet_cidr" {
  description = "CIDR blocks for the Private Subnet"
  type        = list(string)
  default     = ["10.0.2.0/24", "10.0.4.0/24"]

  validation {
    condition     = length(var.private_subnet_cidr) > 0
    error_message = "You must provide at least one CIDR block for private subnets."
  }
}


# Specifies the AWS CLI Profile that TF will use to authenticate 
variable "aws_profile" {
  description = "AWS CLI Profile to use"
  type        = string
  default     = "default"
}

# Amazon Machine Image (AMI) id used to launch instance 
variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
  default     = "ami-085386e29e44dacd7"
}

# EC2 Instance Type; defines the instance typer of EC2 server 
variable "instance_type" {
  description = "EC2 Instance Type"
  type        = string
  default     = "t2.micro"
}

# Specifies the name of the SSH key Pair used for accessing EC2 Instance
variable "key_name" {
  description = "Name of the SSH Key Pair for EC2 access"
  type        = string
  default     = "stack_devops_dev_kp" # Ensure this key pair exists in AWS
}

# The name of the IAM Role for EC2 instance (can be customized)
variable "iam_role_name" {
  description = "Name of the IAM Role for EC2 instance"
  type        = string
  default     = "clixx-ec2-ssm-role"
}

# The name of the SSM Read Policy (can be customized)
variable "ssm_policy_name" {
  description = "Name of the SSM Read Policy for EC2"
  type        = string
  default     = "clixx-ssm-read-policy"
}

# The prefix for SSM parameters that EC2 can access
variable "ssm_parameter_prefix" {
  description = "Prefix for SSM Parameter Store (used for secrets)"
  type        = string
  default     = "/clixx/*" # Adjust to preferred prefix
}

variable "kms_key_id" {
  description = "KMS Key ID for SSM Parameter Encryption (optional)"
  type        = string
  default     = "" # Set this to KMS key ID if using KMS-encrypted parameters
}

variable "environment" {
  description = "Environment for the VPC (Development, Staging, Production)"
  type        = string
  default     = "Development" # Change to preferred default value
}

variable "security_group_ids" {
  description = "List of security group IDs for the Launch Template"
  type        = list(string)
  default     = [] # Set this dynamically if you want to automate
}

variable "iam_instance_profile" {
  description = "IAM Instance Profile name for EC2 instances"
  type        = string
  default     = ""
}

variable "aws_access_key_id" {
  description = "AWS Access Key ID for assumed role"
  type        = string
  default     = ""
}

variable "aws_secret_access_key" {
  description = "AWS Secret Access Key for assumed role"
  type        = string
  default     = ""
}

variable "aws_session_token" {
  description = "AWS Session Token for assumed role"
  type        = string
  default     = ""
}


variable "target_group_name" {
  description = "Name of the Target Group for the CliXX Web Application"
  type        = string
  default     = "cliXX-web-tg"
}

variable "target_group_port" {
  description = "The port on which the target group will listen"
  type        = number
  default     = 80
}

variable "target_group_protocol" {
  description = "The protocol used by the target group"
  type        = string
  default     = "HTTP"
}

variable "az_mapping" {
  description = "Mapping of subnets to Availability Zones"
  type        = map(string)
  default = {
    "10.0.1.0/24" = "us-east-1a"
    "10.0.2.0/24" = "us-east-1b"
    "10.0.3.0/24" = "us-east-1c"
  }
}

variable "default_az" {
  description = "Default Availability Zone if mapping is not found"
  type        = string
  default     = "us-east-1a"
}


variable "min_size" {
  description = "Minimum number of instances in the Auto Scaling Group"
  type        = number
  default     = 1 # Set your default value
}

variable "desired_capacity" {
  description = "Desired number of instances in the Auto Scaling Group"
  type        = number
  default     = 1 # Set your default value
}

variable "max_size" {
  description = "Maximum number of instances in the Auto Scaling Group"
  type        = number
  default     = 3 # Set your default value
}


variable "trusted_ssh_cidr" {
  description = "CIDR block for trusted IP for SSH access"
  type        = string
  default     = "0.0.0.0/0" # Allow from anywhere (change this to your IP for security)
}


variable "wp_home_url" {
  description = "WordPress Home URL (e.g., https://clixx.stack-mayowa.com)"
  type        = string
  default     = "https://clixx.stack-mayowa.com" # Default value (can be changed)
}


variable "mount_point" {
  description = "EFS Mount Point Directory"
  type        = string
  default     = "/var/www/html"
}


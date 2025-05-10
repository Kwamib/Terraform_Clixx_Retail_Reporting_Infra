# ================================
# AWS IAM Role Configuration
# ================================
# This IAM Role allows EC2 instances to securely read SSM Parameters

resource "aws_iam_role" "clixx_ec2_role" {
  name = var.iam_role_name
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  })
}

# SSM Read Policy for EC2
# - Allows EC2 instances to securely read SSM Parameters
# - Policy is restricted to the specified SSM Parameter prefix
resource "aws_iam_policy" "ssm_read_policy" {
  name        = var.ssm_policy_name
  description = "Allow EC2 instances to securely read SSM Parameters with KMS Decrypt"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ],
        "Resource": "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${var.ssm_parameter_prefix}"
      },
      {
        "Effect": "Allow",
        "Action": "kms:Decrypt",
        "Resource": "arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/${var.kms_key_id}"
      }
    ]
  })
}


# Attach SSM Policy to IAM Role
resource "aws_iam_role_policy_attachment" "attach_ssm_policy" {
  role       = aws_iam_role.clixx_ec2_role.name
  policy_arn = aws_iam_policy.ssm_read_policy.arn
}

# IAM Instance Profile for EC2
resource "aws_iam_instance_profile" "clixx_iam_instance_profile" {
  name = "clixx-ec2-ssm-profile"
  role = aws_iam_role.clixx_ec2_role.name
}


# ================================
# AWS Launch Template Configuration
# ================================
# This resource creates an AWS Launch Template for the CliXX Retail Application.
resource "aws_launch_template" "clixx_web_app" {
  name_prefix     = "clixx-web-app"
  description     = "Launch Template for CliXX Retail Application"
  image_id        = var.ami_id
  instance_type   = var.instance_type
  key_name        = var.key_name

  # IAM Instance Profile for Secure SSM Access
  iam_instance_profile {
    name = aws_iam_instance_profile.clixx_iam_instance_profile.name
  }

  # Network Configuration 
  network_interfaces {
    associate_public_ip_address = true       # Auto-assign Public IP (for public subnet)
    subnet_id                   = var.subnet_id
    security_groups             = var.security_group_ids 
  }

  # Secure Startup Configuration (User Data)
  user_data = base64encode(file("${path.module}/userdata.sh"))

  # Tagging for Organization and Management
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "CliXX-Retail-App-Instance"  # Instance Name Tag
      Environment = "Development"                # Environment (Development, Staging, Production)
      Application = "CliXX Web App"              # Application Name
      OwnerEmail  = "mayowa.k.babatola@gmail.com" # Owner's Email (for identification)
      StackTeam   = "Stackcloud13"               # Team responsible for this resource
    }
  }

  # Block Device Mappings (Storage Configuration)
  block_device_mappings {
    device_name = "/dev/xvda"        # Default root device
    ebs {
      volume_size           = 8      # Size of the EBS volume (GB)
      volume_type           = "gp3"  # General Purpose SSD (gp3 is recommended)
      delete_on_termination = true   # Automatically delete the volume when instance is terminated
    }
  }
}

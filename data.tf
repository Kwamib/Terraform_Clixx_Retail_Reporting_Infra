# ==========================================
# Data Sources for CliXX Infrastructure
# ==========================================

# Get current AWS caller identity for account info
data "aws_caller_identity" "current" {}

# Fetch available availability zones in the region
data "aws_availability_zones" "available" {
  state = "available"

  # Exclude any AZs that might have limitations
  exclude_names = []

  # Only get AZs that support VPC
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required", "opted-in"]
  }
}

# ==========================================
# IAM Data Sources
# ==========================================

# Use the existing EngineerProfile instance profile (contains Engineer role)
data "aws_iam_instance_profile" "engineer" {
  name = "EngineerProfile"
}

# ==========================================
# Local Variables for Subnet Configuration
# ==========================================

locals {
  # Cost-efficient 2-AZ configuration (recommended)
  # Using first 2 AZs for optimal cost-to-availability ratio
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)

  # Public subnet configuration (2 AZs)
  public_subnet_cidrs = {
    (local.availability_zones[0]) = "10.0.1.0/24" # First AZ
    (local.availability_zones[1]) = "10.0.3.0/24" # Second AZ
  }

  # Private subnet configuration (2 AZs)
  private_subnet_cidrs = {
    (local.availability_zones[0]) = "10.0.2.0/24" # First AZ
    (local.availability_zones[1]) = "10.0.4.0/24" # Second AZ
  }

  # Maps for resource creation
  public_subnet_map  = local.public_subnet_cidrs
  private_subnet_map = local.private_subnet_cidrs

  # Useful locals for other resources
  primary_az   = local.availability_zones[0]
  secondary_az = local.availability_zones[1]

  # Account ID for use in other resources
  account_id = data.aws_caller_identity.current.account_id
}

# ==========================================
# Validation Locals
# ==========================================

locals {
  # Validate we have enough AZs
  validate_azs = length(local.availability_zones) >= 2 ? true : false

  # Validate CIDR blocks don't overlap
  validate_public_cidrs  = length(distinct(values(local.public_subnet_cidrs))) == length(values(local.public_subnet_cidrs))
  validate_private_cidrs = length(distinct(values(local.private_subnet_cidrs))) == length(values(local.private_subnet_cidrs))
}

# Automatically Collect IDs of the Created Public Subnets
data "aws_subnets" "public_subnets" {
  filter {
    name   = "vpc-id"
    values = [aws_vpc.clixx_vpc.id] # Using dynamically created VPC ID
  }

  filter {
    name   = "tag:Type"
    values = ["Public"] # Ensure the Type tag is set in the subnet creation
  }
}

# Data source for existing ACM certificate
data "aws_acm_certificate" "clixx_cert" {
  domain      = "*.stack-mayowa.com"  # The domain name on the certificate
  statuses    = ["ISSUED"]                # Only get certificates that are active
  most_recent = true                     # In case there are multiple matching certificates
}

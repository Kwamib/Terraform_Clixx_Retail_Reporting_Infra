# Create a VPC
resource "aws_vpc" "clixx_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "CliXX-VPC"
  }
}

# Create Public Subnets Dynamically
resource "aws_subnet" "public_subnets" {
  for_each                = toset(var.public_subnet_cidr)
  vpc_id                  = aws_vpc.clixx_vpc.id
  cidr_block              = each.key
  availability_zone       = lookup(var.az_mapping, each.key, var.default_az)
  map_public_ip_on_launch = true

  tags = {
    Name        = "CliXX-Public-Subnet-${each.key}"
    Environment = var.environment
    Type        = "Public"
  }
}



# Create Private Subnets Dynamically with proper AZ assignment
resource "aws_subnet" "private_subnets" {
  for_each = local.private_subnet_map # Use the local map from data.tf

  vpc_id            = aws_vpc.clixx_vpc.id
  cidr_block        = each.value
  availability_zone = each.key # This assigns specific AZ to each subnet

  tags = {
    Name        = "CliXX-Private-Subnet-${each.key}"
    Environment = var.environment
    Type        = "Private"
    AZ          = each.key
  }
}

resource "aws_security_group" "public_sg" {
  name        = "clixx-public-sg"
  description = "Security group for Public Instances"
  vpc_id      = aws_vpc.clixx_vpc.id

  ingress {
    description = "Allow HTTP (Web Traffic)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Add this new ingress block
  ingress {
    description = "Allow HTTPS (Secure Web Traffic)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    description = "Allow EFS (NFS) traffic from Private Network"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # Adjust as needed
  }

  ingress {
    description = "Secure SSH (Port 22) - Only from Trusted IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_ssh_cidr]
  }

  egress {
    description = "Allow All Outbound Traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "clixx-public-sg"
    Environment = var.environment
  }
}



# Internet Gateway for Public Subnets
resource "aws_internet_gateway" "clixx_igw" {
  vpc_id = aws_vpc.clixx_vpc.id

  tags = {
    Name = "CliXX-IGW"
  }
}

# Public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.clixx_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.clixx_igw.id
  }

  tags = {
    Name = "CliXX-Public-RT"
  }
}

# Public Route Table Association
resource "aws_route_table_association" "public_rta" {
  for_each       = aws_subnet.public_subnets
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_rt.id
}

# NAT Gateway for Private Subnets
resource "aws_eip" "nat_eip" {
  domain = "vpc" # Updated for NAT Gateway EIP
}


resource "aws_nat_gateway" "clixx_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = lookup(aws_subnet.public_subnets, "10.0.1.0/24").id # Specify one of your public subnets
}


# Private Route Table
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.clixx_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.clixx_nat.id
  }

  tags = {
    Name = "CliXX-Private-RT"
  }
}

# Private Route Table Association
resource "aws_route_table_association" "private_rta" {
  for_each       = aws_subnet.private_subnets
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_rt.id
}


# Security Group for EFS
resource "aws_security_group" "efs_sg" {
  name_prefix = "clixx-efs-sg"
  description = "Security group for EFS access"
  vpc_id      = aws_vpc.clixx_vpc.id

  # Allow NFS traffic from anywhere in the VPC
  ingress {
    description = "NFS from VPC"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr] # Allow from entire VPC
  }

  # Keep the existing rule too
  ingress {
    description     = "NFS from web tier"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.public_sg.id]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] # Your VPC CIDR
  }

  tags = {
    Name        = "CliXX-EFS-SG"
    Environment = var.environment
  }
}

# EFS Access Point (optional - for better security)
resource "aws_efs_access_point" "clixx_efs_ap" {
  file_system_id = aws_efs_file_system.clixx_efs.id

  root_directory {
    path = "/app"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "0755"
    }
  }

  posix_user {
    gid = 1000
    uid = 1000
  }

  tags = {
    Name        = "CliXX-EFS-AccessPoint"
    Environment = var.environment
  }
}


resource "aws_vpc_endpoint" "efs" {
  vpc_id              = aws_vpc.clixx_vpc.id
  service_name        = "com.amazonaws.${var.aws_region}.elasticfilesystem"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for subnet in aws_subnet.private_subnets : subnet.id]
  security_group_ids  = [aws_security_group.efs_sg.id]
  private_dns_enabled = true
}


# Security Group for the database
resource "aws_security_group" "db_sg" {
  name        = "clixx-db-sg-${var.environment}"
  description = "Security group for CliXX database"
  vpc_id      = aws_vpc.clixx_vpc.id

  # Allow database traffic from web tier only
  ingress {
    from_port       = 3306 # MySQL port from snapshot
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.public_sg.id] # Allow access from web tier
  }

  # No direct outbound access needed for DB
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "CliXX-DB-SG"
    Environment = var.environment
  }
}



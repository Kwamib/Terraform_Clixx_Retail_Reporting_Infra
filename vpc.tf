# Create a VPC
resource "aws_vpc" "clixx_vpc" {
  cidr_block = var.vpc_cidr
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


# Create Private Subnets Dynamically
resource "aws_subnet" "private_subnets" {
  for_each   = toset(var.private_subnet_cidr)
  vpc_id     = aws_vpc.clixx_vpc.id
  cidr_block = each.key

  tags = {
    Name        = "CliXX-Private-Subnet-${each.key}"
    Environment = var.environment
    Type        = "Private"
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

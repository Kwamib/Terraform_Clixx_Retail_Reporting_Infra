# Create a VPC
resource "aws_vpc" "clixx_vpc" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "CliXX-VPC"
  }
}

# Create Public Subnets Dynamically
resource "aws_subnet" "public_subnets" {
  for_each = toset(var.public_subnet_cidr)
  vpc_id   = aws_vpc.clixx_vpc.id
  cidr_block = each.key
  availability_zone = lookup(var.az_mapping, each.key, var.default_az)
  map_public_ip_on_launch = true

  tags = {
    Name        = "CliXX-Public-Subnet-${each.key}"
    Environment = var.environment
    Type        = "Public"
  }
}


# Create Private Subnets Dynamically
resource "aws_subnet" "private_subnets" {
  for_each = toset(var.private_subnet_cidr)
  vpc_id   = aws_vpc.clixx_vpc.id
  cidr_block = each.key

  tags = {
    Name        = "CliXX-Private-Subnet-${each.key}"
    Environment = var.environment
    Type        = "Private"
  }
}


# Create a Security Group for Public Subnets
resource "aws_security_group" "public_sg" {
  name        = "clixx-public-sg"
  description = "Security group for Public Instances"
  vpc_id      = aws_vpc.clixx_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 2049              # NFS Port for EFS
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]   # Example CIDR for private subnet (adjust as needed)
    description = "Allow EFS (NFS) traffic from private network"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
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
  for_each = aws_subnet.public_subnets
  subnet_id = each.value.id
  route_table_id = aws_route_table.public_rt.id
}

# NAT Gateway for Private Subnets
resource "aws_eip" "nat_eip" {
  domain = "vpc"  # Updated for NAT Gateway EIP
}


resource "aws_nat_gateway" "clixx_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = lookup(aws_subnet.public_subnets, "10.0.1.0/24").id  # Specify one of your public subnets
}


# Private Route Table
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.clixx_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.clixx_nat.id
  }

  tags = {
    Name = "CliXX-Private-RT"
  }
}

# Private Route Table Association
resource "aws_route_table_association" "private_rta" {
  for_each = aws_subnet.private_subnets
  subnet_id = each.value.id
  route_table_id = aws_route_table.private_rt.id
}

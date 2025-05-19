# ==========================================
# RDS Database Configuration for CliXX
# ==========================================


# DB Parameter Group - for MySQL 8.0.35 as per snapshot
resource "aws_db_parameter_group" "clixx_db_params" {
  name   = "clixx-db-params-${local.env_name_normalized}"
  family = "mysql8.0" # Matches the snapshot MySQL version

  parameter {
    name  = "max_connections"
    value = var.environment == "production" ? "1000" : "100"
  }

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  tags = {
    Name        = "CliXX DB Parameters"
    Environment = var.environment
  }
}

# DB Subnet Group needed for RDS
resource "aws_db_subnet_group" "clixx_db_subnet_group" {
  name        = "clixx-db-subnet-group-${local.env_name_normalized}" # Fixed the name here
  description = "DB subnet group for CliXX application"
  subnet_ids  = [for subnet in aws_subnet.private_subnets : subnet.id]

  tags = {
    Name        = "CliXX DB Subnet Group"
    Environment = var.environment
  }
}

# AWS RDS instance restored from snapshot
resource "aws_db_instance" "clixx_db_from_snapshot" {
  identifier          = "clixx-db-${local.env_name_normalized}"
  snapshot_identifier = data.aws_db_snapshot.clixx_snapshot.id

  # Instance specifications
  instance_class = var.db_instance_class

  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.clixx_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  publicly_accessible    = false

  # Multi-AZ deployment for high availability in production
  multi_az = var.environment == "development" ? true : false

  # Apply changes immediately or during maintenance window
  apply_immediately = var.environment != "development"

  # Backup configuration
  backup_retention_period = var.environment == "development" ? 7 : 1
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:30-Mon:05:30"

  # Parameter and option groups
  parameter_group_name = aws_db_parameter_group.clixx_db_params.name

  # Final snapshot configuration
  skip_final_snapshot       = var.environment != "development"
  final_snapshot_identifier = var.environment == "development" ? "clixx-db-final-${formatdate("YYYY-MM-DD", timestamp())}" : null

  # Performance insights
  performance_insights_enabled          = true
  performance_insights_retention_period = var.environment == "development" ? 7 : 0

  # Deletion protection
  deletion_protection = var.environment == "development"

  # Engine settings from the snapshot
  engine         = "mysql"
  engine_version = "8.0.35"

  # Port settings matching the snapshot
  port = 3306

  # Tags
  tags = {
    Name        = "CliXX-Database"
    Environment = var.environment
    Application = "CliXX Web App"
    OwnerEmail  = "mayowa.k.babatola@gmail.com"
    StackTeam   = "Stackcloud13"
    RestoreDate = formatdate("YYYY-MM-DD", timestamp())
  }
}

# Resource to store DB endpoint in SSM Parameter Store
resource "aws_ssm_parameter" "db_endpoint" {
  name        = "/clixx/${local.env_name_normalized}/db/endpoint"
  description = "CliXX Database Endpoint"
  type        = "String"
  value       = aws_db_instance.clixx_db_from_snapshot.endpoint

  tags = {
    Environment = var.environment
    Application = "CliXX Web App"
  }
}





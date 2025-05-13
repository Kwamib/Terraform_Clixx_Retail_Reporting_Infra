# Fetching SSM Parameters Securely
data "aws_ssm_parameter" "db_host" {
  name = "/clixx/db_host"
}

data "aws_ssm_parameter" "wp_db_name" {
  name = "/clixx/wp_db_name"
}

data "aws_ssm_parameter" "wp_db_user" {
  name = "/clixx/wp_db_user"
}

data "aws_ssm_parameter" "clixx_db_password" {
  name            = "/clixx/clixx_db_password"
  with_decryption = true # Ensure sensitive values are decrypted
}

data "aws_ssm_parameter" "efs_id" {
  name = "/clixx/efs_id"
}




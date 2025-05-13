
# ================================
# AWS IAM Role Configuration
# ================================
# This IAM Role allows EC2 instances to securely read SSM Parameters

resource "aws_iam_role" "clixx_ec2_role" {
  name = var.iam_role_name
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ec2.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
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
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ],
        "Resource" : "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${var.ssm_parameter_prefix}/*"
      },
      {
        "Effect" : "Allow",
        "Action" : "kms:Decrypt",
        "Resource" : "*"
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
  name_prefix   = "clixx-web-app"
  depends_on    = [aws_subnet.public_subnets]
  description   = "Launch Template for CliXX Retail Application"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  # IAM Instance Profile for Secure SSM Access
  iam_instance_profile {
    name = aws_iam_instance_profile.clixx_iam_instance_profile.name
  }

  # Network Configuration 
  network_interfaces {
    associate_public_ip_address = true # Auto-assign Public IP (for public subnet)
    subnet_id                   = values(aws_subnet.public_subnets)[0].id
    #security_groups             = var.security_group_ids
    security_groups = [aws_security_group.public_sg.id] # Existing SG
  }

  # Secure Startup Configuration (User Data)
  #user_data = base64encode(file("${path.module}/userdata.sh"))

  user_data = base64encode(
    templatefile("${path.module}/userdata.sh", {
      ssm_db_host     = data.aws_ssm_parameter.db_host.value,     # DB Host
      ssm_db_name     = data.aws_ssm_parameter.wp_db_name.value,     # DB Name
      ssm_db_user     = data.aws_ssm_parameter.wp_db_user.value,     # DB User
      ssm_db_password = data.aws_ssm_parameter.clixx_db_password.value, # DB Password
      EFS_ID          = data.aws_ssm_parameter.efs_id.value,  #EFS_ID
      AWS_REGION      = var.aws_region,     # AWS_REGION  
      MOUNT_POINT     = var.mount_point
    })
  )


  # Tagging for Organization and Management
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "CliXX-Retail-App-Instance"   # Instance Name Tag
      Environment = "Development"                 # Environment (Development, Staging, Production)
      Application = "CliXX Web App"               # Application Name
      OwnerEmail  = "mayowa.k.babatola@gmail.com" # Owner's Email (for identification)
      StackTeam   = "Stackcloud13"                # Team responsible for this resource
    }
  }


  # Block Device Mappings (Storage Configuration)
  block_device_mappings {
    device_name = "/dev/xvda" # Default root device
    ebs {
      volume_size           = 8     # Size of the EBS volume (GB)
      volume_type           = "gp2" # General Purpose SSD
      delete_on_termination = true  # Automatically delete the volume when instance is terminated
    }
  }
}



# Load Balancer
resource "aws_lb" "clixx_lb" {
  name               = "clixx-lb"
  internal           = false         # Set to true for internal LB
  load_balancer_type = "application" # "application" for ALB, "network" for NLB
  security_groups    = [aws_security_group.public_sg.id]
  subnets            = [for subnet in aws_subnet.public_subnets : subnet.id]

  tags = {
    Name        = "clixx-lb"
    Environment = "Development"
  }
}

# ================================
# User Data Validation (Python)
# ================================
/* resource "null_resource" "validate_userdata_vars" {
  depends_on = [aws_launch_template.clixx_web_app] # Ensure template is defined

  provisioner "local-exec" {
    command = "python3 ${path.module}/validate_userdata.py"
  }
} */

# Load Balancer Listener
/* resource "aws_lb_listener" "clixx_listener" {
  load_balancer_arn = aws_lb.clixx_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.clixx_web_tg.arn
  }
}
 */

 # HTTP Listener (Redirects to HTTPS)
resource "aws_lb_listener" "clixx_http_listener" {
  load_balancer_arn = aws_lb.clixx_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      protocol = "HTTPS"
      port     = "443"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS Listener (Secure with SSL)
resource "aws_lb_listener" "clixx_https_listener" {
  load_balancer_arn = aws_lb.clixx_lb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08" # Recommended SSL Policy
  certificate_arn   = "arn:aws:acm:us-east-1:957573079780:certificate/f463c49f-3502-4ffc-87bf-ca78c2219a3d" # Your SSL Certificate ARN

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.clixx_web_tg.arn
  }
}


# Target Group
resource "aws_lb_target_group" "clixx_web_tg" {
  name        = var.target_group_name
  port        = var.target_group_port
  protocol    = var.target_group_protocol
  vpc_id      = aws_vpc.clixx_vpc.id
  target_type = "instance"

  health_check {
    protocol            = "HTTP"
    path                = "/"
    matcher             = "200-299"
    interval            = 60
    timeout             = 15
    healthy_threshold   = 5
    unhealthy_threshold = 3
  }

  tags = {
    Name        = var.target_group_name
    Environment = "Development"
  }
}

resource "aws_autoscaling_group" "clixx_asg" {
  launch_template {
    id      = aws_launch_template.clixx_web_app.id
    version = "$Latest"
  }

  min_size         = var.min_size
  desired_capacity = var.desired_capacity
  max_size         = var.max_size
  #vpc_zone_identifier = data.aws_subnets.public_subnets.ids
  vpc_zone_identifier = [for subnet in aws_subnet.public_subnets : subnet.id]


  health_check_type         = "ELB" # Use ELB health checks
  health_check_grace_period = 600   # 10 minutes grace period
  force_delete              = true
  wait_for_capacity_timeout = "0"

  target_group_arns = [aws_lb_target_group.clixx_web_tg.arn] # Make sure this Target Group exists

  tag {
    key                 = "Name"
    value               = "clixx-web-asg-instance"
    propagate_at_launch = true
  }
}

# Collect the Instance IDs of the Auto Scaling Group dynamically
data "aws_autoscaling_groups" "clixx_asg" {
  names = [aws_autoscaling_group.clixx_asg.name]
}

data "aws_instances" "clixx_asg_instances" {
  filter {
    name   = "instance-state-name"
    values = ["running"]
  }

  filter {
    name   = "instance.group-name"
    values = [data.aws_autoscaling_groups.clixx_asg.names[0]]
  }
}



# Scale Up Policy (High CPU)
resource "aws_autoscaling_policy" "clixx_scale_up_policy" {
  name                   = "clixx-scale-up-policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.clixx_asg.name
}

# Scale Down Policy (Low CPU)
resource "aws_autoscaling_policy" "clixx_scale_down_policy" {
  name                   = "clixx-scale-down-policy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.clixx_asg.name
}


# Cloudwatch 
# Alarm: High CPU Usage (Scaling Out)
resource "aws_cloudwatch_metric_alarm" "clixx_high_cpu_alarm" {
  alarm_name          = "clixx-high-cpu-usage"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 75  # 75% CPU Utilization
  alarm_description   = "Triggered when CPU exceeds 75% for 2 consecutive minutes."
  actions_enabled     = true
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.clixx_asg.name
  }

  alarm_actions = [aws_autoscaling_policy.clixx_scale_up_policy.arn]
}

# Alarm: Low CPU Usage (Scaling In)
resource "aws_cloudwatch_metric_alarm" "clixx_low_cpu_alarm" {
  alarm_name          = "clixx-low-cpu-usage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 30  # 30% CPU Utilization
  alarm_description   = "Triggered when CPU goes below 30% for 2 consecutive minutes."
  actions_enabled     = true
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.clixx_asg.name
  }

  alarm_actions = [aws_autoscaling_policy.clixx_scale_down_policy.arn]
}



resource "aws_sns_topic" "cloudwatch_alarms_topic" {
  name = "clixx-cloudwatch-alarms"
}

resource "aws_sns_topic_subscription" "alarm_subscription" {
  topic_arn = aws_sns_topic.cloudwatch_alarms_topic.arn
  protocol  = "email"
  endpoint  = "your-email@example.com"  # 🔔 Replace with your email
}




# Cloudwatch Dashboard
resource "aws_cloudwatch_dashboard" "clixx_dashboard" {
  dashboard_name = "CliXX-Monitoring-Dashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric",
        x = 0,
        y = 0,
        width = 12,
        height = 6,
        properties = {
          view = "timeSeries",
          title = "CPU Utilization (Auto Scaling Group)",
          region = "us-east-1",
          metrics = [
            [ "AWS/EC2", "CPUUtilization", "AutoScalingGroupName", "${aws_autoscaling_group.clixx_asg.name}" ]
          ],
          period = 60,
          stat = "Average",
          annotations = {
            horizontal = [
              {
                label = "Scale-Out Threshold (75%)",
                value = 75,
                color = "#ff0000",
                fill  = "above"
              },
              {
                label = "Scale-In Threshold (20%)",
                value = 20,
                color = "#00ff00",
                fill  = "below"
              }
            ]
          }
        }
      },
      {
        type = "metric",
        x = 0,
        y = 7,
        width = 12,
        height = 6,
        properties = {
          view = "timeSeries",
          title = "Unhealthy Hosts (ALB Target Group)",
          region = "us-east-1",
          metrics = [
            [ "AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", "${aws_lb.clixx_lb.name}", "TargetGroup", "${aws_lb_target_group.clixx_web_tg.name}" ]
          ],
          period = 60,
          stat = "Sum"
        }
      },
      {
        type = "metric",
        x = 13,
        y = 0,
        width = 12,
        height = 6,
        properties = {
          view = "timeSeries",
          title = "Request Count (ALB)",
          region = "us-east-1",
          metrics = [
            [ "AWS/ApplicationELB", "RequestCount", "LoadBalancer", "${aws_lb.clixx_lb.name}" ]
          ],
          period = 60,
          stat = "Sum"
        }
      },
      {
        type = "metric",
        x = 13,
        y = 7,
        width = 12,
        height = 6,
        properties = {
          view = "timeSeries",
          title = "Healthy Hosts (ALB Target Group)",
          region = "us-east-1",
          metrics = [
            [ "AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", "${aws_lb.clixx_lb.name}", "TargetGroup", "${aws_lb_target_group.clixx_web_tg.name}" ]
          ],
          period = 60,
          stat = "Average"
        }
      }
    ]
  })
}


# ================================
# EFS Configuration
# ================================

# EFS File System
resource "aws_efs_file_system" "clixx_efs" {
  creation_token = "clixx-efs-${var.environment}"
  encrypted      = true

  # Performance settings
  performance_mode = "generalPurpose" # or "maxIO" for high performance
  throughput_mode  = "bursting"       # or "provisioned" if you need guaranteed throughput

  # Lifecycle policy for cost optimization
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name        = "CliXX-EFS"
    Environment = var.environment
    Application = "CliXX Web App"
    OwnerEmail  = "mayowa.k.babatola@gmail.com"
    StackTeam   = "Stackcloud13"
  }
}

# EFS Mount Targets (one in each private subnet)
resource "aws_efs_mount_target" "clixx_efs_mount" {
  for_each = aws_subnet.private_subnets

  file_system_id  = aws_efs_file_system.clixx_efs.id
  subnet_id       = each.value.id
  security_groups = [aws_security_group.efs_sg.id]
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

  # Network Configuration 
  network_interfaces {
    associate_public_ip_address = true # Auto-assign Public IP (for public subnet)
    #subnet_id                   = values(aws_subnet.public_subnets)[0].id
    security_groups             = [aws_security_group.public_sg.id] # Existing SG
  }

  iam_instance_profile {
    name = data.aws_iam_instance_profile.engineer.name
  }

  # Secure Startup Configuration (User Data)
  user_data = base64encode(
    templatefile("${path.module}/userdata.sh", {
      EFS_ID      = aws_efs_file_system.clixx_efs.dns_name #EFS_ID
      MOUNT_POINT = "/var/www/html"
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

  # Additional EBS volumes for LVM
  block_device_mappings {
    device_name = "/dev/sdb"
    ebs {
      volume_size           = 8
      volume_type           = "gp2"
      delete_on_termination = true
    }
  }
  
  block_device_mappings {
    device_name = "/dev/sdc"
    ebs {
      volume_size           = 8
      volume_type           = "gp2"
      delete_on_termination = true
    }
  }
  
  block_device_mappings {
    device_name = "/dev/sdd"
    ebs {
      volume_size           = 8
      volume_type           = "gp2"
      delete_on_termination = true
    }
  }
  
  block_device_mappings {
    device_name = "/dev/sde"
    ebs {
      volume_size           = 8
      volume_type           = "gp2"
      delete_on_termination = true
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



# Load Balancer Listener
resource "aws_lb_listener" "clixx_listener" {
  load_balancer_arn = aws_lb.clixx_lb.arn
  port              = 80
  protocol          = "HTTP"

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
    path                = "/healthcheck.html"
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
  threshold           = 75 # 75% CPU Utilization
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
  threshold           = 30 # 30% CPU Utilization
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
  endpoint  = "your-email@example.com" #Replace with email
}



# Cloudwatch Dashboard
resource "aws_cloudwatch_dashboard" "clixx_dashboard" {
  dashboard_name = "CliXX-Monitoring-Dashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric",
        x      = 0,
        y      = 0,
        width  = 12,
        height = 6,
        properties = {
          view   = "timeSeries",
          title  = "CPU Utilization (Auto Scaling Group)",
          region = var.aws_region,
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", "${aws_autoscaling_group.clixx_asg.name}"]
          ],
          period = 60,
          stat   = "Average",
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
        type   = "metric",
        x      = 0,
        y      = 7,
        width  = 12,
        height = 6,
        properties = {
          view   = "timeSeries",
          title  = "Unhealthy Hosts (ALB Target Group)",
          region = var.aws_region,
          metrics = [
            ["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", "${aws_lb.clixx_lb.name}", "TargetGroup", "${aws_lb_target_group.clixx_web_tg.name}"]
          ],
          period = 60,
          stat   = "Sum"
        }
      },
      {
        type   = "metric",
        x      = 13,
        y      = 0,
        width  = 12,
        height = 6,
        properties = {
          view   = "timeSeries",
          title  = "Request Count (ALB)",
          region = var.aws_region,
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", "${aws_lb.clixx_lb.name}"]
          ],
          period = 60,
          stat   = "Sum"
        }
      },
      {
        type   = "metric",
        x      = 13,
        y      = 7,
        width  = 12,
        height = 6,
        properties = {
          view   = "timeSeries",
          title  = "Healthy Hosts (ALB Target Group)",
          region = var.aws_region,
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", "${aws_lb.clixx_lb.name}", "TargetGroup", "${aws_lb_target_group.clixx_web_tg.name}"]
          ],
          period = 60,
          stat   = "Average"
        }
      }
    ]
  })
}
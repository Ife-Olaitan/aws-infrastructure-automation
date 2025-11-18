terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.99.1"
    }
  }
}

# Get the latest Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Launch Template - Defines EC2 instance configuration (AMI, type, user-data, etc.)
resource "aws_launch_template" "ec2_launch_template" {
  name_prefix   = "${var.environment}-app-"
  description   = "Launch template for ${var.environment} application servers"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name

  # IAM Instance Profile
  iam_instance_profile {
    name = var.iam_instance_profile_name
  }

  # Network Configuration
  network_interfaces {
    # Enabling public IP for Ansible SSH access
    # For production, use a bastion host or AWS Systems Manager instead
    associate_public_ip_address = true
    security_groups             = [var.security_group_id]
    delete_on_termination       = true
  }

  # User Data - Bootstrap Script
  user_data = base64encode(file("${path.module}/user-data.sh"))

  # Root Volume Configuration
  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  # Monitoring
  monitoring {
    enabled = true
  }

  # Tag Specifications
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name        = "${var.environment}-app-server"
      Environment = var.environment
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name        = "${var.environment}-app-volume"
      Environment = var.environment
    }
  }

  # Lifecycle
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${var.environment}-app-launch-template"
    Environment = var.environment
  }
}

# Auto Scaling Group - Manages EC2 instances with auto-scaling and self-healing
resource "aws_autoscaling_group" "app" {
  name = "${var.environment}-app-asg"

  # Launch Template Configuration
  launch_template {
    id      = aws_launch_template.ec2_launch_template.id
    version = "$Latest"
  }

  # Network Configuration
  vpc_zone_identifier = var.subnet_ids

  # Capacity Configuration
  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  # Health Check Configuration
  # Using EC2 health checks initially to allow app deployment
  # Change to "ELB" after initial deployment for application-level health checks
  health_check_type         = "EC2"
  health_check_grace_period = 300

  # Load Balancer Configuration
  target_group_arns = var.target_group_arns

  # Instance Refresh
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  # Termination Policies
  termination_policies = ["OldestInstance"]

  # Enable metrics collection
  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]

  # Tags
  tag {
    key                 = "Name"
    value               = "${var.environment}-app-server"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  # Lifecycle
  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity]
  }
}

# Scale Up Policy - Add one instance when triggered
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.environment}-app-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.app.name
}

# Scale Down Policy - Remove one instance when triggered
resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.environment}-app-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.app.name
}

# High CPU Alarm - Triggers scale up when CPU > 70%
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.environment}-app-cpu-high"
  alarm_description   = "Trigger scale up when CPU exceeds 70%"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 70
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }
}

# Low CPU Alarm - Triggers scale down when CPU < 30%
resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${var.environment}-app-cpu-low"
  alarm_description   = "Trigger scale down when CPU drops below 30%"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 30
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }
}

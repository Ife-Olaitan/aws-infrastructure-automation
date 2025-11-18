terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.99.1"
    }
  }
}

# ECR Repositories - Store Docker images privately in AWS
resource "aws_ecr_repository" "main" {
  for_each = toset(var.repository_names)

  name                 = "${var.environment}-${each.value}"
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  tags = {
    Name        = "${var.environment}-${each.value}"
    Environment = var.environment
  }
}

# Lifecycle Policy - Cleanup old untagged images to save costs
resource "aws_ecr_lifecycle_policy" "main" {
  for_each = aws_ecr_repository.main

  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Delete untagged images after ${var.lifecycle_policy_days} days"
      selection = {
        tagStatus   = "untagged"
        countType   = "sinceImagePushed"
        countUnit   = "days"
        countNumber = var.lifecycle_policy_days
      }
      action = {
        type = "expire"
      }
    }]
  })
}

output "repository_urls" {
  description = "Map of repository names to their URLs"
  value = {
    for k, v in aws_ecr_repository.main : k => v.repository_url
  }
}

output "repository_arns" {
  description = "Map of repository names to their ARNs"
  value = {
    for k, v in aws_ecr_repository.main : k => v.arn
  }
}

output "backend_repository_url" {
  description = "URL of the backend ECR repository"
  value       = aws_ecr_repository.main["backend"].repository_url
}

output "frontend_repository_url" {
  description = "URL of the frontend ECR repository"
  value       = aws_ecr_repository.main["frontend"].repository_url
}
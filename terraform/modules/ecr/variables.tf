variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "repository_names" {
  description = "List of ECR repository names to create"
  type        = list(string)
  default     = ["backend", "frontend"]
}

variable "image_tag_mutability" {
  description = "Tag mutability setting for the repository (MUTABLE or IMMUTABLE)"
  type        = string
  default     = "MUTABLE"
}

variable "scan_on_push" {
  description = "Enable vulnerability scanning on image push"
  type        = bool
  default     = true
}

variable "lifecycle_policy_days" {
  description = "Number of days to keep untagged images"
  type        = number
  default     = 7
}

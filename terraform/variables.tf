variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "eloquent-ai"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "num_azs" {
  description = "Number of availability zones"
  type        = number
  default     = 2
}

variable "ecr_repository_name" {
  description = "Name of the ECR repository"
  type        = string
  default     = "eloquent-ai-app"
}

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
  default     = "eloquent-ai-cluster"
}

variable "ecs_service_name" {
  description = "Name of the ECS service"
  type        = string
  default     = "eloquent-ai-service"
}

variable "container_name" {
  description = "Name of the container"
  type        = string
  default     = "eloquent-ai-app"
}

variable "container_image" {
  description = "Docker image to run (will be overridden by CI/CD)"
  type        = string
  default     = "149399235178.dkr.ecr.us-east-1.amazonaws.com/eloquent-ai-app:latest"
}

variable "container_port" {
  description = "Port exposed by the container"
  type        = number
  default     = 8080
}

variable "task_cpu" {
  description = "CPU units for the task"
  type        = string
  default     = "256"
}

variable "task_memory" {
  description = "Memory for the task in MB"
  type        = string
  default     = "512"
}

variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 2
}

variable "min_capacity" {
  description = "Minimum number of tasks for autoscaling"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum number of tasks for autoscaling"
  type        = number
  default     = 4
}

variable "app_version" {
  description = "Application version"
  type        = string
  default     = "1.0.0"
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

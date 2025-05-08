# Project variables
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "schedule-generator"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

# S3 variables
variable "s3_bucket_name_prefix" {
  description = "Prefix for S3 bucket name"
  type        = string
  default     = "leocorp-frontend"
}

# CloudFront variables
variable "cloudfront_price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_100" # Use PriceClass_All for global distribution
}

variable "cloudfront_default_ttl" {
  description = "Default TTL for CloudFront cache"
  type        = number
  default     = 3600
}

# WAF variables
variable "waf_rate_limit" {
  description = "Rate limit for WAF (requests per 5 minutes)"
  type        = number
  default     = 2000
}

# Lambda variables
variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 128
}

# Cognito variables
variable "cognito_password_min_length" {
  description = "Minimum length for Cognito user passwords"
  type        = number
  default     = 8
}

# AppSync variables
variable "appsync_log_level" {
  description = "AppSync logging level"
  type        = string
  default     = "ERROR" # Options: ERROR, ALL, NONE
}

# VPC variables
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones to use"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# Fargate variables
variable "fargate_cpu" {
  description = "Fargate CPU units (1 vCPU = 1024 units)"
  type        = number
  default     = 1024
}

variable "fargate_memory" {
  description = "Fargate memory in MiB"
  type        = number
  default     = 2048
}

# Schedule generator variables
variable "schedule_generator_image" {
  description = "Docker image for the schedule generator"
  type        = string
  default     = "latest"
}
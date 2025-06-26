variable "bucket_name_prefix" {
  description = "Prefix for bucket names"
  type        = string
  default     = "leonardo-project-v2"
}

# AWS account ID and region references are defined in main.tf

variable "name_suffix" {
  description = "Sufijo único para nombres de recursos"
  type        = string
  default     = "20250625-2220"
}

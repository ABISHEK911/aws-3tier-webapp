variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short name used to prefix resource names"
  type        = string
  default     = "3tier-webapp"
}

variable "db_password" {
  description = "Master password for RDS. Set via TF_VAR_db_password environment variable — never commit this to a file."
  type        = string
  sensitive   = true
}
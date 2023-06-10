variable "database_name" {
  description = "Wordpress database name"
  type        = string
  default     = "my-wordpress-db"
}

variable "database_username" {
  description = "Wordpress database master username"
  type        = string
  default     = "admin"
}

variable "database_password" {
  description = "Wordpress database master username"
  type        = string
  default     = "password123"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

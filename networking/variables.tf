variable "vpc_cidr" {
  type = string
  description = "The VPC cidr"
}

variable "enable_dns_support" {
  type = bool
}

variable "enable_dns_hostnames" {
  type = bool
}

variable "enable_classiclink" {
  type = bool
}

variable "enable_classiclink_dns_support" {
  type = bool
}

variable "public_sn_count" {
  type        = number
  description = "Number of public subnets"
}

variable "private_sn_count" {
  type        = number
  description = "Number of private subnets"
}

variable "tags" {
  description = "A mapping of tags to assign to all resources."
  type        = map(string)
  default     = {}
}

variable "public_cidr" {}

variable "private_cidr" {}

variable "name" {
  type    = string
  default = "main"
}

variable "environment" {
  type = string
  default = "environment"
}

variable "security_group" {}
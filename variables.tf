variable "region" {
  type = string
  description = "The region to deploy resources"
}

variable "name" {
  type    = string
  default = "main"

}

variable "tags" {
  description = "A mapping of tags to assign to all resources."
  type        = map(string)
  default     = {}
}

variable "ami" {
  type        = string
  description = "AMI ID for the launch template"
}

variable "keypair" {
  type        = string
  description = "key pair for the instances"
}

variable "account_no" {
  type        = number
  description = "the account number"
}

variable "master-username" {
  type        = string
  description = "RDS admin username"
}

variable "master-password" {
  type        = string
  description = "RDS master password"
}

// variable "max_subnets" {
//   default = 10
// }

variable "environment" {
  type = string
}


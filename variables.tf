variable "region" {
  type = string
  description = "The region to deploy resources"
  default = "us-east-1"
}

variable "vpc_cidr" {
  type = string
  description = "The VPC cidr"
  default = "172.16.0.0/16" 
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
  default = "ami-09e67e426f25ce0d7"
}

variable "keypair" {
  type        = string
  description = "key pair for the instances"
  default = "terraform-ec2"
}

variable "account_no" {
  type        = number
  description = "the account number"
  default = "323678568700"
}

variable "master-username" {
  type        = string
  description = "RDS admin username"
  default = "rotimi"
}

variable "master-password" {
  type        = string
  description = "RDS master password"
  default = "devopspblproject"
}

variable "environment" {
  type = string
  default = production
}


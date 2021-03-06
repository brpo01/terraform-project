variable "vpc_id" {}

variable "ext-alb-sg" {}

variable "int-alb-sg" {}

variable "public_subnet0" {}

variable "public_subnet1" {}

variable "private_subnet0" {}

variable "private_subnet1" {}

variable "certificate_arn" {}

variable "tags" {
  description = "A mapping of tags to assign to all resources."
  type        = map(string)
  default     = {}
}
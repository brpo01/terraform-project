variable "tags" {
  description = "A mapping of tags to assign to all resources."
  type        = map(string)
  default     = {}
}

variable "ami" {}

variable "bastion-sg" {}

variable "nginx-sg" {}

variable "webserver-sg" {}

variable "bastion_user_data" {}

variable "nginx_user_data" {}

variable "tooling_user_data" {}

variable "wordpress_user_data" {}

variable "keypair" {}
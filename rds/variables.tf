variable "private_subnet2" {}

variable "private_subnet3" {}

variable "master-username" {}

variable "master-password" {}

variable "datalayer-sg" {}

variable "tags" {
  description = "A mapping of tags to assign to all resources."
  type        = map(string)
  default     = {}
}
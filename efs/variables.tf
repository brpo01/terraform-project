variable "private_subnet0" {}

variable "private_subnet1" {}

variable "datalayer-sg" {}

variable "tags" {
  description = "A mapping of tags to assign to all resources."
  type        = map(string)
  default     = {}
}

variable "account_no" {}
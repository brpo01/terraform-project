region = "us-east-1"

vpc_cidr = "172.16.0.0/16" 

environment = "production"

ami = "ami-09e67e426f25ce0d7"

keypair = "terraform-ec2"

# Ensure to change this to your acccount number
account_no = "323678568700"

master-username = "rotimi"

master-password = "devopspblproject"

tags = {
  Enviroment      = "production" 
  Owner-Email     = "opraise00@gmail.com"
  Managed-By      = "Terraform"
  Billing-Account = "1234567890"
}
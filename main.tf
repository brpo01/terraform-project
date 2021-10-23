module "networking" {
  source = "./networking"
  
  public_subnets = var.preferred_number_of_public_subnets
}
module "networking" {
  source = "./networking"
  vpc_cidr = var.vpc_cidr
  enable_dns_support             = var.enable_dns_support
  enable_dns_hostnames           = var.enable_dns_hostnames
  enable_classiclink             = var.enable_classiclink
  enable_classiclink_dns_support = var.enable_classiclink_dns_support
  public_subnets = var.preferred_number_of_public_subnets
  public_cidr = [for i in range(2,6,2) : cidrsubnet(var.vpc_cidr, 8, i)]
  private_subnets = var.preferred_number_of_private_subnets
  private_cidr = [for i in range(1,9,2): cidrsubnet(var.vpc_cidr, 8, i)]
}
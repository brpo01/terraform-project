module "networking" {
  source = "./networking"
  vpc_cidr = var.vpc_cidr
  enable_dns_support             = true
  enable_dns_hostnames           = true
  enable_classiclink             = true
  enable_classiclink_dns_support = true
  public_sn_count = 2
  public_cidr = [for i in range(2,6,2) : cidrsubnet(var.vpc_cidr, 8, i)]
  private_sn_count = 4
  private_cidr = [for i in range(1,9,2): cidrsubnet(var.vpc_cidr, 8, i)]
}

module "security" {
  source = "./security"
  security_group = local.security_group
  vpc_id = module.networking.vpc_id
}

module "alb" {
  source = "./alb"
  
}

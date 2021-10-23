module "networking" {
  source = "./networking"
  vpc_cidr = var.vpc_cidr
  enable_dns_support             = true
  enable_dns_hostnames           = true
  enable_classiclink             = false
  enable_classiclink_dns_support = false
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

module "loadbalancing" {
  source = "./loadbalancing"
  ext-alb-sg = module.security.ext-alb
  public_subnet = module.networking.public_subnet
  vpc_id = module.networking.vpc_id
  int-alb-sg = module.security.int-alb
  private_subnet0 = module.networking.private_subnet0
  private_subnet1 = module.networing.private_subnet1
  certificate_arn = module.certificate.cert_validation_arn
}

module "certificate" {
  source = "./certificate"
  ext-alb-dns-name = module.loadbalancing.ext-alb-dns-name
  ext-alb-zone-id = module.loadbalancing.ext-alb-zone-id
}

module "efs" {
  source = "./efs"
  private_subnet0 = module.networking.private_subnet0
  private_subnet1 = module.networking.private_subnet1
  datalayer-sg = module.security.datalayer
}

module "rds" {
  source = "./rds"
  private_subnet2 = module.networking.private_subnet2
  private_subnet3 = module.networking.private_subnet3
  master-username = var.master-username
  master-password = var.master-password
  datalayer-sg = module.security.datalayer
}

module "compute" {
  source = "./compute"
  ami = var.ami
  bastion-sg = module.security.bastion
  nginx-sg = module.security.nginx
  webserver-sg = module.security.webservers
  keypair = var.keypair
  bastion_user_data = filebase64("${path.module}/bastion.sh")
  nginx_user_data = filebase64("${path.module}/nginx.sh")
  wordpress_user_data = filebase64("${path.module}/wordpress.sh")
  tooling_user_data = filebase64("${path.module}/tooling.sh")
}
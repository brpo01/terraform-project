# Get list of availability zones
data "aws_availability_zones" "available" {
    state = "available"
}

# Create a random reosurce for shuffling availability zones for the subnet resources
// resource "random_shuffle" "az-list" {
//   input = data.aws_availability_zones.available.names
//   result_count = var.max_subnets
// }

# Create VPC
resource "aws_vpc" "main" {
  cidr_block                     = var.vpc_cidr
  enable_dns_support             = var.enable_dns_support
  enable_dns_hostnames           = var.enable_dns_hostnames
  enable_classiclink             = var.enable_classiclink
  enable_classiclink_dns_support = var.enable_classiclink_dns_support

  tags = merge(
    var.tags,
    {
      Name = "main-vpc"
    }
  )
}

# Create public subnets
resource "aws_subnet" "public_subnet" {
  count = var.public_sn_count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_cidr[count.index]
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index]

  tags = merge(
    var.tags,
    {
      Name = format("public-subnet-%s", count.index)
    }
  )
}

# Create public subnets
resource "aws_subnet" "private_subnet" {
  count = var.private_sn_count
  vpc_id = aws_vpc.main.id
  cidr_block = var.private_cidr[count.index]
  map_public_ip_on_launch = true
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = merge(
    var.tags,
    {
      Name = format("private-subnet-%s", count.index)
    }
  )
}

# internet gateway
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = format("%s-%s!", "ig-",aws_vpc.main.id)
    } 
  )
}

# Elastic ip resource
resource "aws_eip" "nat_eip" {
  vpc        = true
  depends_on = [aws_internet_gateway.main_igw]

  tags = merge(
    var.tags,
    {
      Name = format("%s-EIP-%s", var.name, var.environment)
    },
  )
}

# nat gateway resource
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = element(aws_subnet.public_subnet.*.id, 0)
  depends_on    = [aws_internet_gateway.main_igw]

  tags = merge(
    var.tags,
    {
      Name = format("%s-Nat-%s", var.name, var.environment)
    },
  )
}

# create private route table
resource "aws_route_table" "private-rtb" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = format("%s-Private-Route-Table", var.name)
    },
  )
}

# associate all private subnets to the private route table
resource "aws_route_table_association" "private-subnets-assoc" {
  count          = length(aws_subnet.private_subnet[*].id)
  subnet_id      = element(aws_subnet.private_subnet[*].id, count.index)
  route_table_id = aws_route_table.private-rtb.id
}

# create route for the private route table and attach the nat gateway
resource "aws_route" "private-rtb-route" {
  route_table_id         = aws_route_table.private-rtb.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_nat_gateway.nat.id
}

# create route table for the public subnets
resource "aws_route_table" "public-rtb" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = format("%s-Public-Route-Table", var.name)
    },
  )
}

# associate all public subnets to the public route table
resource "aws_route_table_association" "public-subnets-assoc" {
  count          = length(aws_subnet.public_subnet[*].id)
  subnet_id      = element(aws_subnet.public_subnet[*].id, count.index)
  route_table_id = aws_route_table.public-rtb.id
}

# create route for the public route table and attach the internet gateway
resource "aws_route" "public-rtb-route" {
  route_table_id         = aws_route_table.public-rtb.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main_igw.id
}

# security group for external alb, to allow acess from any where for HTTP and HTTPS traffic
# security group for bastion, to allow access into the bastion host from you IP

resource "aws_security_group" "main-sg" {
  for_each = var.security_group
  name   = each.value.name
  description = each.value.description
  vpc_id = aws_vpc.main.id

  dynamic "ingress" {
    for_each = each.value.ingress
    content {
      from_port   = ingress.value.from
      to_port     = ingress.value.to
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
      {
        for_each = var.security_group
        Name = each.value.name
      },
  )
}

# security group for nginx reverse proxy, to allow access only from the external load-balancer and bastion instance
resource "aws_security_group_rule" "inbound-nginx-http" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.main-sg["ext-alb"].id
  security_group_id        = aws_security_group.main-sg["nginx"].id
}

resource "aws_security_group_rule" "inbound-bastion-ssh" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.main-sg["bastion"].id
  security_group_id        = aws_security_group.main-sg["nginx"].id
}

# security group for ialb, to have acces only from nginx reverse proxy server
resource "aws_security_group_rule" "inbound-ialb-https" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.main-sg["nginx"].id
  security_group_id        = aws_security_group.main-sg["int-alb"].id
}

# security group for webservers, to have access only from the internal load balancer and bastion instance
resource "aws_security_group_rule" "inbound-web-https" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.main-sg["int-alb"].id
  security_group_id        = aws_security_group.main-sg["webservers"].id
}

resource "aws_security_group_rule" "inbound-web-ssh" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.main-sg["bastion"].id
  security_group_id        = aws_security_group.main-sg["webservers"].id
}

# security group for datalayer to allow traffic from webserver on nfs and mysql port and bastion host on mysql port
resource "aws_security_group_rule" "inbound-nfs-port" {
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.main-sg["webservers"].id
  security_group_id        = aws_security_group.main-sg["datalayer"].id
}

resource "aws_security_group_rule" "inbound-mysql-bastion" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.main-sg["bastion"].id
  security_group_id        = aws_security_group.main-sg["datalayer"].id
}

resource "aws_security_group_rule" "inbound-mysql-webserver" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.main-sg["webservers"].id
  security_group_id        = aws_security_group.main-sg["datalayer"].id
}
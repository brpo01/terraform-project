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

# Create public subnets1
resource "aws_subnet" "public_subnet" {
  count = var.public_subnets
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_cidr
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index]

  tags = merge(
    var.tags,
    {
      Name = format("public-subnet-%s", count.index)
    }
  )
}

resource "aws_subnet" "private_subnet" {
  count = var.private_subnets
  vpc_id = aws_vpc.main.id
  cidr_block = var.private_cidr
  map_public_ip_on_launch = true
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = merge(
    var.tags,
    {
      Name = format("private-subnet-%s", count.index)
    }
  )
}


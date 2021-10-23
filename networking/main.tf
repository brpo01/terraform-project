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
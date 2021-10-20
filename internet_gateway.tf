resource "aws_internet_gateway" "main-igw" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = format("%s-%s!", "ig-",aws_vpc.main.id)
    } 
  )
}
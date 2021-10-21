# Elastic ip resource
resource "aws_eip" "nat_eip" {
  vpc        = true
  depends_on = [aws_internet_gateway.main_igw]

  tags = merge(
    var.tags,
    {
      Name = format("%s-EIP", var.name, var.environment)
    },
  )
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = element(aws_subnet.public_subnet.*.id, 0)
  depends_on    = [aws_internet_gateway.main_igw]

  tags = merge(
    var.tags,
    {
      Name = format("%s-Nat", var.name, var.environment)
    },
  )
}
output "vpc_id" {
    value = aws_vpc.main.id
}

output "public_subnet0" {
    value = aws_subnet.public_subnet[0].id
}

output "public_subnet1" {
    value = aws_subnet.public_subnet[1].id
}

output "private_subnet0" {
    value = aws_subnet.private_subnet[0].id
}

output "private_subnet1" {
    value = aws_subnet.private_subnet[1].id
}

output "private_subnet2" {
    value = aws_subnet.private_subnet[2].id
}

output "private_subnet3" {
    value = aws_subnet.private_subnet[3].id
}
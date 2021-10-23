output "ext-alb" {
    value = aws_security_group.main-sg["ext-alb"].id
}

output "bastion" {
    value = aws_security_group.main-sg["bastion"].id
}

output "int-alb" {
    value = aws_security_group.main-sg["int-alb"].id
}

output "nginx" {
    value = aws_security_group.main-sg["nginx"].id
}

output "webservers" {
    value = aws_security_group.main-sg["webservers"].id
}

output "datalayer" {
    value = aws_security_group.main-sg["datalayer"].id
}
# security group for external alb, to allow acess from any where for HTTP and HTTPS traffic
# security group for bastion, to allow access into the bastion host from you IP

resource "aws_security_group" "main-sg" {
  for_each = var.security_group
  name   = each.value.name
  description = each.value.description
  vpc_id = var.vpc_id

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
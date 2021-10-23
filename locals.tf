locals {
    security_group = {
        ext-alb = {
            name = "ext-alb"
            description = "Security Group for Ext-Alb"
            ingress = {
                http = {
                    from = 80
                    to = 80
                    protocol = "tcp"
                    cidr_blocks = [0.0.0.0/0]
                }

                https = {
                    from = 80
                    to = 80
                    protocol = "tcp"
                    cidr_blocks = [0.0.0.0/0]
                }
            }
        }
        bastion = {
            name = "Bastion"
            description = "Bastion Security Group"
            ingress = {
                ssh = {
                    from = 22
                    to = 22
                    protocol = "tcp"
                    cidr_blocks = [0.0.0.0/0]
                }
            }
        }
        Nginx = {
            name = "Nginx"
            description = "Nginx Security Group"
            ingress = {
                https = {
                    from = 443
                    to = 443
                    protocol = "tcp"
                    cidr_blocks = [0.0.0.0/0]
                }
            }
        }
        int-alb = {
            name = "int-alb"
            description = "Internal Loadbalancer Security Group"
            ingress = {
                ssh = {
                    from = 443
                    to = 443
                    protocol = "tcp"
                    cidr_blocks = [0.0.0.0/0]
                }
            }
        }
    }
}
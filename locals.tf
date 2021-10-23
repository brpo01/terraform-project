locals {
    security_group = {
        ext-alb = {
            name = "External Loadbalancer"
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
            description = "Security Group Bastion"
            ingress = {
                ssh = {
                    from = 22
                    to = 22
                    protocol = "tcp"
                    cidr_blocks = [0.0.0.0/0]
                }
            }
        }
    }
}
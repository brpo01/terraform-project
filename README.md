## AUTOMATE INFRASTRUCTURE WITH IAC USING TERRAFORM.

In this documentation, we'll be automating the provisioning of aws infrastructure with terraform using the architecture below. We'll also be configuring aws s3 bucket as a remote backend to store state files and DynamoDB for state locking & consistency checking.

![tooling_project_15](https://user-images.githubusercontent.com/76074379/126079856-ac2b5dea-45d0-4f1f-85fa-54284a91a5de.png)

## Introducing Backend on AWS S3
Each Terraform configuration can specify a backend, which defines where and how operations are performed, where state snapshots are stored, etc.
Take a peek into what the states file looks like. It is basically where terraform stores all the state of the infrastructure in json format.

So far, we have been using the default backend, which is the local backend – it requires no configuration, and the states file is stored locally. This mode can be suitable for learning purposes, but it is not a robust solution, so it is better to store it in some more reliable and durable storage.

The second problem with storing this file locally is that, in a team of multiple DevOps engineers, other engineers will not have access to a state file stored locally on your computer.

To solve this, we will need to configure a backend where the state file can be accessed remotely other DevOps team members. There are plenty of different standard backends supported by Terraform that you can choose from. Since we are already using AWS – we can choose an S3 bucket as a backend.

Another useful option that is supported by S3 backend is State Locking – it is used to lock your state for all operations that could write state. This prevents others from acquiring the lock and potentially corrupting your state. State Locking feature for S3 backend is optional and requires another AWS service – DynamoDB.

Here is our plan to Re-initialize Terraform to use S3 backend:

- Add S3 and DynamoDB resource blocks before deleting the local state file.
- Update terraform block to introduce backend and locking
- Re-initialize terraform
- Delete the local tfstate file and check the one in S3 bucket
- Add outputs
- Run "terraform apply"

Now let us begin configuring the remote backend

- Create a file and name it backends.tf. Add the below code. Before you initialize create an s3 bucket resource on your aws account and use the name you specified in your code - "dev-terraform-bucket". You must also be aware that Terraform stores secret data inside the state files. Passwords, and secret keys processed by resources are always stored in there. Hence, you must consider to always enable encryption. You can see how we achieved that with server_side_encryption_configuration.

```
# Note: The bucket name may not work for you since buckets are unique globally in AWS, so you must give it a unique name.
resource "aws_s3_bucket" "terraform_state" {
  bucket = "dev-terraform-bucket"
  # Enable versioning so we can see the full revision history of our state files
  versioning {
    enabled = true
  }
  # Enable server-side encryption by default
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}
```
- Create a DynamoDB table to handle locks and perform consistency checks. In previous projects, locks were handled with a local file as shown in terraform.tfstate.lock.info. Since we now have a team mindset, causing us to configure S3 as our backend to store state file, we will do the same to handle locking. Therefore, with a cloud storage database like DynamoDB, anyone running Terraform against the same infrastructure can use a central location to control a situation where Terraform is running at the same time from multiple different people.

```
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}
```
- Run **terraform apply** to create both resources. Terraform expects that both S3 bucket and DynamoDB resources are already created before we configure the backend. So, let us run terraform apply to provision resources.

- Configure S3 Backend

```
terraform {
  backend "s3" {
    bucket         = "dev-terraform-bucket"
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

- Now its time to re-initialize the backend. Run terraform init and confirm you are happy to change the backend by typing yes. You have successfully migrated your state file form your local machine to a remote s3 bucket. Terraform will automatically read the latest state from the S3 bucket to determine the current state of the infrastructure.

![1](https://user-images.githubusercontent.com/47898882/138969545-119e9b3f-c424-4bd3-9978-03524f3c8ff7.JPG)

![3](https://user-images.githubusercontent.com/47898882/138969558-a5a79639-61e0-4c52-a318-9a002b956efb.JPG)

![4](https://user-images.githubusercontent.com/47898882/138969539-3df67ea4-6ed8-469d-b120-8b55149a6b35.JPG)

- Add the code below to the outputs.tf file

```
output "s3_bucket_arn" {
  value       = aws_s3_bucket.terraform_state.arn
  description = "The ARN of the S3 bucket"
}
output "dynamodb_table_name" {
  value       = aws_dynamodb_table.terraform_locks.name
  description = "The name of the DynamoDB table"
}
```

## Terraform Modules and best practices to structure your .tf codes

Modules serve as containers that allow to logically group Terraform codes for similar resources in the same domain (e.g., Compute, Networking, AMI, etc.). One root module can call other child modules and insert their configurations when applying Terraform config. This concept makes your code structure neater, and it allows different team members to work on different parts of configuration at the same time.

You can also create and publish your modules to Terraform Registry for others to use and use someone’s modules in your projects.

Module is just a collection of .tf and/or .tf.json files in a directory.

You can refer to existing child modules from your root module by specifying them as a source, like this:

```
module "networking" {
  source = "./networking"
}
```

## Refactor Your Project Using Modules

- Break down your Terraform codes to have all resources in their respective modules. Combine resources of a similar type into directories within a directory, for example, like this:

```
  - Loadbalancing
  - EFS
  - RDS
  - Autoscaling
  - Compute
  - Networking
  - Security
  - Certificate
```
 - Each module shall contain following files:

```
- main.tf (or %resource_name%.tf) file(s) with resources blocks
- outputs.tf (optional, if you need to refer outputs from any of these resources in your root module)
- variables.tf (it is a good practice not to hard code the values and use variables)
```

- It is also recommended to configure providers and backends sections in separate files. Now let us break our terraform code into modules

### Compute Module

- Create a folder called compute and add these three files - main.tf, variables.tf & outputs.tf

- Move roles.tf & the launch templates into the main.tf file in the compute folder.

- Add outputs in the outputs.tf. We'll be referencing these outputs in the root main.tf file. Also create a user-data folder for your user-data scripts 

**main.tf**
```
resource "aws_iam_role" "ec2_instance_role" {
  name = "ec2_instance_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "aws assume role"
    },
  )
}

resource "aws_iam_policy" "policy" {
  name        = "ec2_instance_policy"
  description = "A test policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:Describe*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]

  })

  tags = merge(
    var.tags,
    {
      Name =  "aws assume policy"
    },
  )

}

resource "aws_iam_role_policy_attachment" "test-attach" {
    role       = aws_iam_role.ec2_instance_role.name
    policy_arn = aws_iam_policy.policy.arn
}

resource "aws_iam_instance_profile" "ip" {
    name = "aws_instance_profile_test"
    role =  aws_iam_role.ec2_instance_role.name
}

data "aws_availability_zones" "available" {}

resource "random_shuffle" "az_list" {
  input    = data.aws_availability_zones.available.names
}

# ---- Launch templates for bastion  hosts

resource "aws_launch_template" "bastion-launch-template" {
  image_id               = var.ami
  instance_type          = "t2.micro"
  vpc_security_group_ids = [var.bastion-sg]

  iam_instance_profile {
    name = aws_iam_instance_profile.ip.id
  }

  key_name = var.keypair

  placement {
    availability_zone = "random_shuffle.az_list.result"
  }

  lifecycle {
    create_before_destroy = true
  }

  tag_specifications {
    resource_type = "instance"

   tags = merge(
    var.tags,
    {
      Name = "bastion-launch-template"
    },
  )
  }

  user_data = var.bastion_user_data
}

#--------- launch template for nginx

resource "aws_launch_template" "nginx-launch-template" {
  image_id               = var.ami
  instance_type          = "t2.micro"
  vpc_security_group_ids = [var.nginx-sg]

  iam_instance_profile {
    name = aws_iam_instance_profile.ip.id
  }

  key_name =  var.keypair

  placement {
    availability_zone = "random_shuffle.az_list.result"
  }

  lifecycle {
    create_before_destroy = true
  }

  tag_specifications {
    resource_type = "instance"

    tags = merge(
    var.tags,
    {
      Name = "nginx-launch-template"
    },
  )
  }

  user_data = var.nginx_user_data
}

# launch template for wordpress

resource "aws_launch_template" "wordpress-launch-template" {
  image_id               = var.ami
  instance_type          = "t2.micro"
  vpc_security_group_ids = [var.webserver-sg]

  iam_instance_profile {
    name = aws_iam_instance_profile.ip.id
  }

  key_name = var.keypair

  placement {
    availability_zone = "random_shuffle.az_list.result"
  }

  lifecycle {
    create_before_destroy = true
  }

  tag_specifications {
    resource_type = "instance"

    tags = merge(
    var.tags,
    {
      Name = "wordpress-launch-template"
    },
  )

  }

  user_data = var.wordpress_user_data
}

# launch template for toooling
resource "aws_launch_template" "tooling-launch-template" {
  image_id               = var.ami
  instance_type          = "t2.micro"
  vpc_security_group_ids = [var.webserver-sg]

  iam_instance_profile {
    name = aws_iam_instance_profile.ip.id
  }

  key_name = var.keypair

  placement {
    availability_zone = "random_shuffle.az_list.result"
  }

  lifecycle {
    create_before_destroy = true
  }

  tag_specifications {
    resource_type = "instance"

  tags = merge(
    var.tags,
    {
      Name = "tooling-launch-template"
    },
  )

  }

  user_data = var.tooling_user_data
}
```

**variables.tf**

```
variable "ami" {}

variable "bastion-sg" {}

variable "nginx-sg" {}

variable "webserver-sg" {}

variable "bastion_user_data" {}

variable "nginx_user_data" {}

variable "tooling_user_data" {}

variable "wordpress_user_data" {}

variable "keypair" {}

variable "tags" {
  description = "A mapping of tags to assign to all resources."
  type        = map(string)
  default     = {}
}
```

**outputs.tf**

```
output "bastion_launch_template" {
    value = aws_launch_template.bastion-launch-template.id
}

output "nginx_launch_template" {
    value = aws_launch_template.nginx-launch-template.id
}

output "wordpress_launch_template" {
    value = aws_launch_template.wordpress-launch-template.id
}

output "tooling_launch_template" {
    value = aws_launch_template.tooling-launch-template.id
}
```

**root main.tf**

```
module "compute" {
  source = "./compute"
  ami = var.ami
  bastion-sg = module.security.bastion
  nginx-sg = module.security.nginx
  webserver-sg = module.security.webservers
  keypair = var.keypair
  bastion_user_data = filebase64("${path.module}/user-data/bastion.sh")
  nginx_user_data = filebase64("${path.module}/user-data/nginx.sh")
  wordpress_user_data = filebase64("${path.module}/user-data/wordpress.sh")
  tooling_user_data = filebase64("${path.module}/user-data/tooling.sh")
}
```

### Networking Module

- Create a folder called networking and add these three files - main.tf, variables.tf & outputs.tf.

- Move internetgateway.tf, natgateway.tf into the main.tf file in the networking folder. Also move the the VPC & subnets originally in the root main.tf into the networking folder.

- Add outputs in the outputs.tf. We'll be referencing these outputs in the root main.tf file.

**main.tf**

```
# Get list of availability zones
data "aws_availability_zones" "available" {
    state = "available"
}

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

  lifecycle {
    create_before_destroy = true 
  }
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
```

**variables.tf**

```
variable "vpc_cidr" {
  type = string
  description = "The VPC cidr"
}

variable "enable_dns_support" {
  type = bool
}

variable "enable_dns_hostnames" {
  type = bool
}

variable "enable_classiclink" {
  type = bool
}

variable "enable_classiclink_dns_support" {
  type = bool
}

variable "public_sn_count" {
  type        = number
  description = "Number of public subnets"
}

variable "private_sn_count" {
  type        = number
  description = "Number of private subnets"
}

variable "tags" {
  description = "A mapping of tags to assign to all resources."
  type        = map(string)
  default     = {}
}

variable "public_cidr" {}

variable "private_cidr" {}

variable "name" {
  type    = string
  default = "main"
}

variable "environment" {
  type = string
  default = "production"
}
```

**outputs.tf**

```
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
```

**root main.tf**

```
module "networking" {
  source = "./networking"
  vpc_cidr = var.vpc_cidr
  enable_dns_support             = true
  enable_dns_hostnames           = true
  enable_classiclink             = false
  enable_classiclink_dns_support = false
  public_sn_count = 2
  public_cidr = [for i in range(2,6,2) : cidrsubnet(var.vpc_cidr, 8, i)]
  private_sn_count = 4
  private_cidr = [for i in range(1,9,2): cidrsubnet(var.vpc_cidr, 8, i)]
}
```

### Loadbalancing Module

- Create a folder called loadbalancing and add these three files - main.tf, variables.tf & outputs.tf.

- Move ext-alb.tf & int-alb.tf into the main.tf file in the loadbalancing folder. 

- Add outputs in the outputs.tf file. We'll be referencing these outputs in the root main.tf file. 

**main.tf**

```
// external loadbalancer resource to direct traffic to the public subnet
resource "aws_lb" "ext-alb" {
  name     = "ext-alb"
  internal = false
  security_groups = [
    var.ext-alb-sg
  ]

  subnets = [
    var.public_subnet0,
    var.public_subnet1
  ]

   tags = merge(
    var.tags,
    {
      Name = "main-ext-alb"
    },
  )

  ip_address_type    = "ipv4"
  load_balancer_type = "application"
}

// nginx target group resource to inform loadbalancer where to route traffic
resource "aws_lb_target_group" "nginx-tgt" {
  health_check {
    interval            = 10
    path                = "/healthstatus"
    protocol            = "HTTPS"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }
  name        = "nginx-tgt"
  port        = 443
  protocol    = "HTTPS"
  target_type = "instance"
  vpc_id      = var.vpc_id

  lifecycle {
    ignore_changes = [name]
    create_before_destroy = true
  }
}

// loadbalancer listener resource for knowing what port to listen & route traffic to target group
resource "aws_lb_listener" "nginx-listener" {
  load_balancer_arn = aws_lb.ext-alb.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx-tgt.arn
  }
}

# ----------------------------
#Internal Load Balancers for webservers
#---------------------------------

resource "aws_lb" "ialb" {
  name     = "ialb"
  internal = true
  security_groups = [
    var.int-alb-sg
  ]

  subnets = [
    var.private_subnet0,
    var.private_subnet1
  ]

  tags = merge(
    var.tags,
    {
      Name = "main-int-alb"
    },
  )

  ip_address_type    = "ipv4"
  load_balancer_type = "application"
}

# --- target group  for wordpress -------

resource "aws_lb_target_group" "wordpress-tgt" {
  health_check {
    interval            = 10
    path                = "/healthstatus"
    protocol            = "HTTPS"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }

  name        = "wordpress-tgt"
  port        = 443
  protocol    = "HTTPS"
  target_type = "instance"
  vpc_id      = var.vpc_id

   lifecycle {
    ignore_changes = [name]
    create_before_destroy = true
  }
}

# --- target group for tooling -------

resource "aws_lb_target_group" "tooling-tgt" {
  health_check {
    interval            = 10
    path                = "/healthstatus"
    protocol            = "HTTPS"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }

  name        = "tooling-tgt"
  port        = 443
  protocol    = "HTTPS"
  target_type = "instance"
  vpc_id      = var.vpc_id

   lifecycle {
    ignore_changes = [name]
    create_before_destroy = true
  }
}

# For this aspect a single listener was created for the wordpress which is default,
# A rule was created to route traffic to tooling when the host header changes

resource "aws_lb_listener" "web-listener" {
  load_balancer_arn = aws_lb.ialb.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress-tgt.arn
  }
}

# listener rule for tooling target

resource "aws_lb_listener_rule" "tooling-listener" {
  listener_arn = aws_lb_listener.web-listener.arn
  priority     = 99

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tooling-tgt.arn
  }

  condition {
    host_header {
      values = ["tooling.dev-rotimi.ml"]
    }
  }
}
```

**outputs.tf** 

```
output "alb_dns_name" {
  value = aws_lb.ext-alb.dns_name
}

output "alb_target_group_arn" {
  value = aws_lb_target_group.nginx-tgt.arn
}

output "ext-alb-zone-id" {
    value = aws_lb.ext-alb.zone_id
}

output "ext-alb-dns-name" {
    value = aws_lb.ext-alb.dns_name
}

output "nginx_tgt_arn" {
    value = aws_lb_target_group.nginx-tgt.arn
}

output "wordpress_tgt_arn" {
    value = aws_lb_target_group.wordpress-tgt.arn
}

output "tooling_tgt_arn" {
    value = aws_lb_target_group.tooling-tgt.arn
}
```

**root main.tf**

```
module "loadbalancing" {
  source = "./loadbalancing"
  ext-alb-sg = module.security.ext-alb
  public_subnet0 = module.networking.public_subnet0
  public_subnet1 = module.networking.public_subnet1
  vpc_id = module.networking.vpc_id
  int-alb-sg = module.security.int-alb
  private_subnet0 = module.networking.private_subnet0
  private_subnet1 = module.networking.private_subnet1
  certificate_arn = module.certificate.cert_validation_arn
}
```

### EFS Module

- Create a folder called efs and add these three files - main.tf, variables.tf & outputs.tf.

- Move efs.tf & kms.tf into the main.tf file in the efs folder. 

- Add outputs in the outputs.tf file. We'll be referencing these outputs in the root main.tf file.

**main.tf**

```
# create key from key management system
resource "aws_kms_key" "main-kms" {
  description = "KMS key "
  policy      = <<EOF
  {
  "Version": "2012-10-17",
  "Id": "kms-key-policy",
  "Statement": [
    {
      "Sid": "Enable IAM User Permissions",
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::${var.account_no}:user/Toby" },
      "Action": "kms:*",
      "Resource": "*"
    }
  ]
}
EOF
}

# create key alias
resource "aws_kms_alias" "alias" {
  name          = "alias/kms"
  target_key_id = aws_kms_key.main-kms.key_id
}

# create Elastic file system
resource "aws_efs_file_system" "main-efs" {
  encrypted  = true
  kms_key_id = aws_kms_key.main-kms.arn

  tags = merge(
    var.tags,
    {
      Name = "main-efs"
    },
  )
}

# set first mount target for the EFS 
resource "aws_efs_mount_target" "subnet-1" {
  file_system_id  = aws_efs_file_system.main-efs.id
  subnet_id       = var.private_subnet0
  security_groups = [var.datalayer-sg]
}

# set second mount target for the EFS 
resource "aws_efs_mount_target" "subnet-2" {
  file_system_id  = aws_efs_file_system.main-efs.id
  subnet_id       = var.private_subnet1
  security_groups = [var.datalayer-sg]
}

# create access point for wordpress
resource "aws_efs_access_point" "wordpress" {
  file_system_id = aws_efs_file_system.main-efs.id

  posix_user {
    gid = 0
    uid = 0
  }

  root_directory {
    path = "/wordpress"

    creation_info {
      owner_gid   = 0
      owner_uid   = 0
      permissions = 0755
    }

  }
}

# create access point for tooling
resource "aws_efs_access_point" "tooling" {
  file_system_id = aws_efs_file_system.main-efs.id
  posix_user {
    gid = 0
    uid = 0
  }

  root_directory {

    path = "/tooling"

    creation_info {
      owner_gid   = 0
      owner_uid   = 0
      permissions = 0755
    }

  }
}
```

**variables.tf**

```
variable "private_subnet0" {}

variable "private_subnet1" {}

variable "datalayer-sg" {}

variable "tags" {
  description = "A mapping of tags to assign to all resources."
  type        = map(string)
  default     = {}
}

variable "account_no" {}
```

**root main.tf**

```
module "efs" {
  source = "./efs"
  account_no = var.account_no
  private_subnet0 = module.networking.private_subnet0
  private_subnet1 = module.networking.private_subnet1
  datalayer-sg = module.security.datalayer
}
```

### Certificate Module

- Create a folder called certificate and add these three files - main.tf, variables.tf & outputs.tf.

- Move cert.tf into the main.tf file in the certificate folder.

- Add outputs in the outputs.tf file. We'll be referencing these outputs in the root main.tf file.

**main.tf**

```
# The entire section create a certiface, public zone, and validate the certificate using DNS method

# Create the certificate using a wildcard for all the domains created in dev-rotimi.ml
resource "aws_acm_certificate" "rotimi" {
  domain_name       = "*.dev-rotimi.ml"
  validation_method = "DNS"
}

# calling the hosted zone- create the hosted zone in your route53 console
data "aws_route53_zone" "rotimi" {
  name         = "dev-rotimi.ml"
  private_zone = false
}

# selecting validation method
resource "aws_route53_record" "rotimi" {
  for_each = {
    for dvo in aws_acm_certificate.rotimi.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.rotimi.zone_id
}

# validate the certificate through DNS method
resource "aws_acm_certificate_validation" "rotimi" {
  certificate_arn         = aws_acm_certificate.rotimi.arn
  validation_record_fqdns = [for record in aws_route53_record.rotimi : record.fqdn]
}

# create records for tooling
resource "aws_route53_record" "tooling" {
  zone_id = data.aws_route53_zone.rotimi.zone_id
  name    = "tooling.dev-rotimi.ml"
  type    = "A"

  alias {
    name                   = var.ext-alb-dns-name
    zone_id                = var.ext-alb-zone-id
    evaluate_target_health = true
  }
}

# create records for wordpress
resource "aws_route53_record" "wordpress" {
  zone_id = data.aws_route53_zone.rotimi.zone_id
  name    = "wordpress.dev-rotimi.ml"
  type    = "A"

  alias {
    name                   = var.ext-alb-dns-name
    zone_id                = var.ext-alb-zone-id
    evaluate_target_health = true
  }
}
```

**variables.tf**

```
variable "ext-alb-dns-name" {}

variable "ext-alb-zone-id" {}
```

**outputs.tf**
```
output "cert_validation_arn" {
    value = aws_acm_certificate_validation.rotimi.certificate_arn
}
```

**root main.tf**

```
module "certificate" {
  source = "./certificate"
  ext-alb-dns-name = module.loadbalancing.ext-alb-dns-name
  ext-alb-zone-id = module.loadbalancing.ext-alb-zone-id
}
```

### RDS Module

- Create a folder called rds and add these three files - main.tf, variables.tf & outputs.tf.

- Move rds.tf into the main.tf file in the certificate folder.

- Add outputs in the outputs.tf file. We'll be referencing these outputs in the root main.tf file.

**main.tf**

```
# This section will create the subnet group for the RDS  instance using the private subnet
resource "aws_db_subnet_group" "main-rds" {
  name       = "main-rds"
  subnet_ids = [var.private_subnet2, var.private_subnet3]

 tags = merge(
    var.tags,
    {
      Name = "main-rds"
    },
  )
}

# create the RDS instance with the subnets group
resource "aws_db_instance" "main-rds" {
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t2.micro"
  name                   = "maindb"
  username               = var.master-username
  password               = var.master-password
  parameter_group_name   = "default.mysql5.7"
  db_subnet_group_name   = aws_db_subnet_group.main-rds.name
  skip_final_snapshot    = true
  vpc_security_group_ids = [var.datalayer-sg]
  multi_az               = "true"

  tags = merge(
    var.tags,
    {
      Name = "maindb"
    },
  )
}
```

**variables.tf**

```
variable "private_subnet2" {}

variable "private_subnet3" {}

variable "master-username" {}

variable "master-password" {}

variable "datalayer-sg" {}

variable "tags" {
  description = "A mapping of tags to assign to all resources."
  type        = map(string)
  default     = {}
}
```

**root main.tf**

```
module "rds" {
  source = "./rds"
  private_subnet2 = module.networking.private_subnet2
  private_subnet3 = module.networking.private_subnet3
  master-username = var.master-username
  master-password = var.master-password
  datalayer-sg = module.security.datalayer
}
```

### Security Module

- Create a folder called security and add these three files - main.tf, variables.tf & outputs.tf.

- Move security.tf into the main.tf file in the security folder.

- Add outputs in the outputs.tf file. We'll be referencing these outputs in the root main.tf file.

**main.tf**

```
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
```

**variables.tf**

```
variable "vpc_id" {}

variable "security_group" {}

variable "tags" {
  description = "A mapping of tags to assign to all resources."
  type        = map(string)
  default     = {}
}
```

**outputs.tf**

```
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
```

**root main.tf**

```
module "security" {
  source = "./security"
  security_group = local.security_group
  vpc_id = module.networking.vpc_id
}
```

### Autoscaling Module

- Create a folder called autoscaling and add these three files - main.tf, variables.tf & outputs.tf.

- Move autoscaling group into the main.tf file in the autoscaling folder.

- Add outputs in the outputs.tf file. We'll be referencing these outputs in the root main.tf file.

**main.tf** 

```
// Creating sns topic for all the auto scaling groups
resource "aws_sns_topic" "rotimi-sns" {
    name = "Default_CloudWatch_Alarms_Topic"
}

// Creating Notifications for all autoscaling groups
resource "aws_autoscaling_notification" "rotimi_notifications" {
  group_names = [
    aws_autoscaling_group.bastion-asg.name,
    aws_autoscaling_group.nginx-asg.name,
    aws_autoscaling_group.wordpress-asg.name,
    aws_autoscaling_group.tooling-asg.name,
  ]
  notifications = [
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
    "autoscaling:EC2_INSTANCE_TERMINATE_ERROR",
  ]

  topic_arn = aws_sns_topic.rotimi-sns.arn
}

# ---- Autoscaling for bastion  hosts

resource "aws_autoscaling_group" "bastion-asg" {
  name                      = "bastion-asg"
  max_size                  = 2
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "ELB"
  desired_capacity          = 1

  vpc_zone_identifier = [
    var.public_subnet0,
    var.public_subnet1
  ]

  launch_template {
    id      = var.bastion_launch_template
    version = "$Latest"
  }
  tag {
    key                 = "Name"
    value               = "main-bastion"
    propagate_at_launch =  true
  }

}

# ------ Autoscslaling group for reverse proxy nginx ---------

resource "aws_autoscaling_group" "nginx-asg" {
  name                      = "nginx-asg"
  max_size                  = 2
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "ELB"
  desired_capacity          = 1

  vpc_zone_identifier = [
    var.public_subnet0,
    var.public_subnet1
  ]

  launch_template {
    id      = var.nginx_launch_template
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "main-nginx"
    propagate_at_launch = true
  }

}

# attaching autoscaling group of nginx to external load balancer
resource "aws_autoscaling_attachment" "asg_attachment_nginx" {
  autoscaling_group_name = aws_autoscaling_group.nginx-asg.id
  alb_target_group_arn   = var.nginx_tgt_arn
}

# ---- Autoscaling for wordpress application

resource "aws_autoscaling_group" "wordpress-asg" {
  name                      = "wordpress-asg"
  max_size                  = 2
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "ELB"
  desired_capacity          = 1
  vpc_zone_identifier = [
    var.private_subnet0,
    var.private_subnet1
  ]

  launch_template {
    id      = var.wordpress_launch_template
    version = "$Latest"
  }
  tag {
    key                 = "Name"
    value               = "main-wordpress"
    propagate_at_launch = true
  }
}

# attaching autoscaling group of  wordpress application to internal loadbalancer
resource "aws_autoscaling_attachment" "asg_attachment_wordpress" {
  autoscaling_group_name = aws_autoscaling_group.wordpress-asg.id
  alb_target_group_arn   = var.wordpress_tgt_arn
}

# ---- Autoscaling for tooling -----

resource "aws_autoscaling_group" "tooling-asg" {
  name                      = "tooling-asg"
  max_size                  = 2
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "ELB"
  desired_capacity          = 1

  vpc_zone_identifier = [
    var.private_subnet0,
    var.private_subnet1
  ]

  launch_template {
    id      = var.tooling_launch_template
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "main-tooling"
    propagate_at_launch = true
  }
}

# attaching autoscaling group of  tooling application to internal loadbalancer
resource "aws_autoscaling_attachment" "asg_attachment_tooling" {
  autoscaling_group_name = aws_autoscaling_group.tooling-asg.id
  alb_target_group_arn   = var.tooling_tgt_arn
}
```

**outputs.tf**

```
variable "public_subnet0" {}

variable "public_subnet1" {}

variable "bastion_launch_template" {}

variable "nginx_launch_template" {}

variable "wordpress_launch_template" {}

variable "tooling_launch_template" {}

variable "nginx_tgt_arn" {}

variable "private_subnet0" {}

variable "private_subnet1" {}

variable "wordpress_tgt_arn" {}

variable "tooling_tgt_arn" {}
```

**root main.tf**

```
module "autoscaling" {
  source = "./autoscaling"
  public_subnet0 = module.networking.public_subnet0
  public_subnet1 = module.networking.public_subnet1
  bastion_launch_template = module.compute.bastion_launch_template
  nginx_launch_template = module.compute.nginx_launch_template
  nginx_tgt_arn = module.loadbalancing.nginx_tgt_arn
  wordpress_tgt_arn = module.loadbalancing.wordpress_tgt_arn
  tooling_tgt_arn = module.loadbalancing.tooling_tgt_arn
  private_subnet0 = module.networking.private_subnet0
  private_subnet1 = module.networking.private_subnet1
  wordpress_launch_template = module.compute.wordpress_launch_template
  tooling_launch_template = module.compute.tooling_launch_template
```

- Also, Add the following code to the root variables.tf & root outputs.tf file

**root variables.tf**

```
variable "region" {
  type = string
  description = "The region to deploy resources"
}

variable "vpc_cidr" {
  type = string
  description = "The VPC cidr"
}

variable "name" {
  type    = string
  default = "main"
}

variable "tags" {
  description = "A mapping of tags to assign to all resources."
  type        = map(string)
  default     = {}
}

variable "ami" {
  type        = string
  description = "AMI ID for the launch template"
}

variable "keypair" {
  type        = string
  description = "key pair for the instances"
}

variable "account_no" {
  type        = number
  description = "the account number"
}

variable "master-username" {
  type        = string
  description = "RDS admin username"
}

variable "master-password" {
  type        = string
  description = "RDS master password"
}

variable "environment" {
  type = string
}
```

**root outputs.tf**

```
output "alb_dns_name" {
  value = module.loadbalancing.alb_dns_name
}

output "alb_target_group_arn" {
  value = module.loadbalancing.alb_target_group_arn
}

output "s3_bucket_arn" {
  value       = aws_s3_bucket.terraform_state.arn
  description = "The ARN of the S3 bucket"
}
output "dynamodb_table_name" {
  value       = aws_dynamodb_table.terraform_locks.name
  description = "The name of the DynamoDB table"
}
```

- Also, define a terraform.tfvars file to keep your secret outputs.

- Now we are done with refactoring our code into modules. Run *terraform plan* to see all the resources that will be created.

![2](https://user-images.githubusercontent.com/47898882/138969554-04245a17-5d3e-422c-a2b2-58789ddfacd6.JPG)


- Now, the code is much more well-structured and can be easily read, edited and reused

### Congratulations!!..You have automated the provisioning of AWS Infrastructure with Terraform!

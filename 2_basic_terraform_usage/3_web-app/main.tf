terraform {
  # 1) Using the s3 bucket and dynamo DB table we already set up
  backend "s3" {
    bucket         = "my-bucket-1610"
    key            = "02-basics/web-app/terraform.tfstate"  # where the tf state file will be stored
    region         = "us-east-1"
    dynamodb_table = "terraform-state-locking"              # dynamodb table for state locking
    encrypt        = true
  }

  required_providers {            # specifies the provider needed by the tf config
    aws = {                       # uses the aws provider
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {                  # configures specific details for the provider in the config (aws)
  region = "us-east-1"
}

# 2) Compute:
#     2 EC2 instances:
resource "aws_instance" "instance_1" {
  ami             = "ami-011899242bb902164" # Ubuntu 20.04 LTS // us-east-1
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.instances.name] # this is important to set up security groups to enable inbound traffic
  user_data       = <<-EOF
              #!/bin/bash
              echo "Hello, World 1" > index.html
              python3 -m http.server 8080 &
              EOF
}

resource "aws_instance" "instance_2" {
  ami             = "ami-011899242bb902164" # Ubuntu 20.04 LTS // us-east-1
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.instances.name] # this is important to set up security groups to enable inbound traffic
  user_data       = <<-EOF
              #!/bin/bash
              echo "Hello, World 2" > index.html
              python3 -m http.server 8080 &
              EOF
}

# 3) S3 bucket (Storage):
#   (it's not used for anything in particular)
resource "aws_s3_bucket" "bucket" {
  bucket_prefix = "web-app-data"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "bucket_versioning" {
  bucket = aws_s3_bucket.bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bucket_crypto_conf" {
  bucket = aws_s3_bucket.bucket.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 4) We need to specify which vpc and which subnet within that vpc we want our resources to go into
data "aws_vpc" "default_vpc" {
  default = true
}

data "aws_subnet_ids" "default_subnet" {
  vpc_id = data.aws_vpc.default_vpc.id
}

# 4) the security groups defined in line 39 to allow inbound traffic

resource "aws_security_group" "instances" {
  name = "instance-security-group"
}

# adding group rules (like IAM policies)
resource "aws_security_group_rule" "allow_http_inbound" {
  type              = "ingress"                       # allows inbound traffic
  security_group_id = aws_security_group.instances.id

  from_port   = 8080                                  # at port 8080
  to_port     = 8080
  protocol    = "tcp"                                 # using tcp protocol
  cidr_blocks = ["0.0.0.0/0"]                         # allowing all ip adresses
}

# 5) Load Balancer: 
#   lb listener configuration
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.load_balancer.arn

  port = 80

  protocol = "HTTP"

  # By default, return a simple 404 page (if we hit a url that don't recognizes)
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}

# specify where we want to send that traffic by defining a target group (which contains our 2 ec2 instances)
resource "aws_lb_target_group" "instances" {
  name     = "example-target-group"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default_vpc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# attaching the 2 EC2 instances into the target group (so that the load balancer knows where to send the traffic and on what port)
resource "aws_lb_target_group_attachment" "instance_1" {
  target_group_arn = aws_lb_target_group.instances.arn
  target_id        = aws_instance.instance_1.id
  port             = 8080
}

resource "aws_lb_target_group_attachment" "instance_2" {
  target_group_arn = aws_lb_target_group.instances.arn
  target_id        = aws_instance.instance_2.id
  port             = 8080
}

# set up listener rules
resource "aws_lb_listener_rule" "instances" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]  # in this case its going to take all paths
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.instances.arn
  }
}


# 6) some different security groups for the load balancer in terms of the traffic that it's accepting
resource "aws_security_group" "alb" {
  name = "alb-security-group"
}

resource "aws_security_group_rule" "allow_alb_http_inbound" {
  type              = "ingress"                 # allows inbound traffic
  security_group_id = aws_security_group.alb.id

  from_port   = 80                              # on port 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

}

resource "aws_security_group_rule" "allow_alb_all_outbound" {
  type              = "egress"                  # rule for outbund traffic
  security_group_id = aws_security_group.alb.id

  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

}

# 7) Afther the configuration, we can define the Load Balancer itself
resource "aws_lb" "load_balancer" {
  name               = "web-app-lb"
  load_balancer_type = "application"
  subnets            = data.aws_subnet_ids.default_subnet.ids # which subnet to provision into
  security_groups    = [aws_security_group.alb.id]            # wich security groups to use

}

# 8) Route 53 for DNS:
  # allows us to use an actual domain into our browser and access our site
resource "aws_route53_zone" "primary" {
  name = "127.0.0.1"#"devopsdeployed.com" # domain
}

resource "aws_route53_record" "root" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "127.0.0.1"#"devopsdeployed.com"  # the zone "primary" takes trafic to the domain
  type    = "A"
# points the traffic to the load balanacer
  alias {
    name                   = aws_lb.load_balancer.dns_name
    zone_id                = aws_lb.load_balancer.zone_id
    evaluate_target_health = true
  }
}

# 9) RDS Database:
# (like the S3, it's not used for anything in particular)
resource "aws_db_instance" "db_instance" {
  allocated_storage = 20
  # This allows any minor version within the major engine_version
  # defined below, but will also result in allowing AWS to auto
  # upgrade the minor version of your DB. This may be too risky
  # in a real production environment.
  auto_minor_version_upgrade = true
  storage_type               = "standard"
  engine                     = "postgres"
  engine_version             = "11"
  instance_class             = "db.t3.micro"
  name                       = "mydb"
  username                   = "foo"
  password                   = "foobarbaz"  # this won't be hardcoded
  skip_final_snapshot        = true
}
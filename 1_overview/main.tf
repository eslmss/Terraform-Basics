terraform {
  required_providers {
    # defining provider
    aws = {
        source  = "hashicorp/aws"
        version = "~> 3.0"
    }
  }
}

provider "aws" {
  # defining default region for provider "aws"
  region = "us-east-1"
}

resource "aws_instance" "example" {
    # Amazon Machine Image: contains the full set of info required to create an EC2 VM instance
    ami           = "ami-011899242bb902164" # Ubuntu 20.04 LTS // us-east-1
    instance_type = "t2.micro"
}

# terraform init: prepares the workspace so Terraform can apply this configuration
# terraform plan: preview of the changes Terraform will make before applying them
# terraform apply: makes the changes defined by the plan
# terraform destroy: destroys all the resources managed in the actual directory
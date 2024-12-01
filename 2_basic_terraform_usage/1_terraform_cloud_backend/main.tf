# Remote Backend (Terraform Cloud)
# 1) terraform login: to generate an api key in the app.terraform
# 2) on the website: create the organization "terraform-course-directive" and workspace "devops-terraform-course"
# 3) terraform init in this path
# 4) nothing to plan, nothing to destroy
# this alternative is free up to 5 users
terraform {
  backend "remote" {
    organization = "terraform-course-directive"

    workspaces {
      name = "devops-terraform-course"
    }
  }
}
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = "~> 3.0"
#     }
#   }
# }

# provider "aws" {
#   region = "us-east-1"
# }


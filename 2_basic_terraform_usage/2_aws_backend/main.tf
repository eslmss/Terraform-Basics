# Remote Backend (AWS):
terraform {
  # 3) Finally we uncomment the  following code and run -> terraform init. This will migrate the local tf State (Local Backend) to the new s3 backend (Remote Backend)
  # terraform plan
  #############################################################
  ## AFTER RUNNING TERRAFORM APPLY (WITH LOCAL BACKEND)      ##
  ## YOU WILL UNCOMMENT THIS CODE THEN RERUN TERRAFORM INIT  ##
  ## TO SWITCH FROM LOCAL BACKEND TO REMOTE AWS BACKEND      ##
  #############################################################
  backend "s3" {
    bucket         = "my-bucket-1610"             # REPLACE WITH BUCKET NAME
    key            = "tf-infra/terraform.tfstate" # the migrated tf state file will be stored here
    region         = "us-east-1"
    dynamodb_table = "terraform-state-locking"    # offers atomic guarantees for collaborative work (lock/reject applies)
    encrypt        = true
  }

# 1) Local Backend:
# this will provision the resources and then import them into the configuration.
# First we specify our terraform config with no remote backend (default Local Backend -> tf State will be stored locally)
required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# 2) We define the resources that we need (s3 bucket and dynamodb table). In the step 3) the tf state will be stored in the s3 for a Remote Backend
#     terraform init
#     terraform apply
resource "aws_s3_bucket" "terraform_state" {
  bucket        = "my-bucket-1610" # REPLACE WITH BUCKET NAME
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "terraform_bucket_versioning" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_crypto_conf" {
  bucket        = aws_s3_bucket.terraform_state.bucket 
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-state-locking"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID" # this is critical to ensure uniqueness, efficiency and compatibility in tf state locking mechanism
  attribute {
    name = "LockID"
    type = "S"
  }
}
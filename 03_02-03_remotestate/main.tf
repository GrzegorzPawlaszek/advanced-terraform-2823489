# //////////////////////////////
# BACKEND
# //////////////////////////////
terraform {
  backend "s3" {
    # tu jest mozliwość dalszej konfiguracji, ale poniewaz są to dane wraźliwe lepiej jest to wynieść np. do CLI i odpalić tak:

    # terraform init \
    # -backend-config="bucket=red30-tfstate-gregp" \
    # -backend-config="key=red30/ecommerceapp/app.state" \
    # -backend-config="region=us-east-2" \
    # -backend-config="dynamodb_table=red30-tfstatelock" \
    # -backend-config="access_key={key}" \
    # -backend-config="secret_key={secret}"
  }
}

# //////////////////////////////
# VARIABLES
# //////////////////////////////
variable "aws_access_key" {}

variable "aws_secret_key" {}

variable "region" {
  default = "us-east-2"
}

variable "vpc_cidr" {
  default = "172.16.0.0/16"
}

variable "subnet1_cidr" {
  default = "172.16.0.0/24"
}

# //////////////////////////////
# PROVIDERS
# //////////////////////////////
provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.region
}


# //////////////////////////////
# MODULES
# //////////////////////////////
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "vpc-module-example"

  cidr = "10.0.0.0/16"

  azs             = ["us-east-2a", "us-east-2b", "us-east-2c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
}
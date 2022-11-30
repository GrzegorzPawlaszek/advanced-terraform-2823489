# //////////////////////////////
# VARIABLES
# //////////////////////////////
variable "aws_access_key" {}

variable "aws_secret_key" {}

variable "region" {
  default = "us-east-2"
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
# SECURITY GROUP
# //////////////////////////////
resource "aws_security_group" "sg_frontend" {
  name   = "sg_frontend"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

# //////////////////////////////
# MODULES
# //////////////////////////////
module "vpc" {
  # ten moduł jest na registry.terraform.io i zostanie sciągnięty razem z providerem podczas terraform apply
  source = "terraform-aws-modules/vpc/aws"
  # name jest opcjonalny, potrzebny gdybyśmy chcieli uzyć tego modułu kilka razy do utworzenia wielu VPC
  name = "frontend-vpc"
  # zakres adresów dla VPC
  cidr = "10.0.0.0/16"

# podsieci muszą mieć zdefiniowane zony, bo AWS musi wiedzieć w której AZ stworzyć podsieci
# ten moduł pozwala zadeklarować listę stref i sam pod spodem utworzy tam podsieci
  azs             = ["us-east-2a", "us-east-2b", "us-east-2c"]
# tu są zasięgi dla prywatnych i publicznych podsieci
# zasoby w prywatnych podsieciach muszą być podpięte pod NAT gateway, aby mieć dostęp do internetu
# kazda podsieć zostanie utworzony w osobnej AZ. 
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

# ustawienie tego na true utworzy nat gateway
  enable_nat_gateway = true
# tu określamy, ze chcemy mieć jeden wspólny nat gateway dla wszystkich prywatnych podsieci
  single_nat_gateway = true
  # one_nat_gateway_per_az = true

# dodatkowo aby mieć dostęp do internetu, poza internet gateway, potrzeba jeszcze wpis do routing table 
# i połaczenie tego ze sobą
# I tego wszystkiego nie trzeba robić, bo ten moduł zrobi to pod spodem
}


# //////////////////////////////
# DATA
# //////////////////////////////
data "aws_ami" "aws-linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn-ami-hvm*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
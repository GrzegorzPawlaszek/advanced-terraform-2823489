# //////////////////////////////
# VARIABLES
# //////////////////////////////
# moźna uswatiać zmienne podczas uruchomienia za pomocą pliku, albo z CLI
variable "aws_access_key" {}

variable "aws_secret_key" {}

variable "ssh_key_name" {}

variable "private_key_path" {}

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
# provider to implementacja interejsu terraforma dla konkretnego dostawcy, tu AWS'a
# choć normalnie nie powinno być tak, ze kazda osobna EC2 będzie miała swój adres DNS
provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.region
}

# //////////////////////////////
# RESOURCES
# //////////////////////////////

# VPC
# wszystkie kolejne zasoby sieciowe będą wew. tej sieci
resource "aws_vpc" "vpc1" {
  cidr_block = var.vpc_cidr
  # to ustawienie sprawi, ze dla kazdej EC2 tworzonej w tej sieci powstanie automatycznie adres DNS
  enable_dns_hostnames = "true"
  tags = {
    Name = "test_vpc"
  }
}

# SUBNET
resource "aws_subnet" "subnet1" {
  cidr_block = var.subnet1_cidr
  vpc_id = aws_vpc.vpc1.id
  map_public_ip_on_launch = "true"
  availability_zone = data.aws_availability_zones.available.names[1]
}

# INTERNET_GATEWAY
# umozliwia kontakt z internetem
# wystarczy podać do jakie sieci ma być podłączony gateway
resource "aws_internet_gateway" "gateway1" {
  vpc_id = aws_vpc.vpc1.id
}

# ROUTE_TABLE
# trzeba zdefiniować, aby przekierować ruch z podsieci do gateway'a
# nie ma natomiast tutaj mapowanie na konkretną podsiec
resource "aws_route_table" "route_table1" {
  vpc_id = aws_vpc.vpc1.id

  route {
    # ten wpis określa, ze kazda sieć wew naszej VPC będzie mogła się połączyć z gatewayem 
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway1.id
  }
}

# tu mamy połączenie między konkretną podsiecią, a route table
# co ciekawe nigdzie juz więcej nie ma odniesienia do tego zasobu
resource "aws_route_table_association" "route-subnet1" {
  subnet_id = aws_subnet.subnet1.id
  route_table_id = aws_route_table.route_table1.id
}

# SECURITY_GROUP
# ustawia porty wejsia i wyjscia dla wszystkich EC@, które są podłączone do podstawowj sieci VPC
resource "aws_security_group" "sg-nodejs-instance" {
  name = "nodejs_sg"
  vpc_id = aws_vpc.vpc1.id

# wejście http
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    # tu określone jest do których adresów ma się odnosić reguła
    cidr_blocks = ["0.0.0.0/0"]
  }

# wejscie TLS
  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
  
    cidr_blocks = ["0.0.0.0/0"]
  }

# wejście SSH - to zostanie usuniete w produkcyjnej konfiguracji
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

# INSTANCE
resource "aws_instance" "nodejs1" {
  ami = data.aws_ami.aws-linux.id
  instance_type = "t2.micro"
  subnet_id = aws_subnet.subnet1.id
  vpc_security_group_ids = [aws_security_group.sg-nodejs-instance.id]
  key_name               = var.ssh_key_name

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ec2-user"
    private_key = file(var.private_key_path)
  }
}


# //////////////////////////////
# DATA
# //////////////////////////////
# tu są zapytania o zew. dane
# pierwszy zapytuje o listę availability zones dla regionu zdefiniowanego przy providerze: tu us-east-2
data "aws_availability_zones" "available" {
  state = "available"
}

# drugi pobiera listę AMI
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

# //////////////////////////////
# OUTPUT
# //////////////////////////////
# zmienna output wypisze adres dns, za pomocą którego przez SSH będzie mozna się połączyć z EC2
output "instance-dns" {
  value = aws_instance.nodejs1.public_dns
}
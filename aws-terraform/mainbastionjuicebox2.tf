# https://developer-shubham-rasal.medium.com/aws-networking-using-terraform-cbbf28dcb124

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
  shared_credentials_files = ["../credentials"]
}

# Create a VPC
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "team_vpc"
  cidr = "10.13.0.0/16"

  azs             = ["us-east-1a"]
  private_subnets = ["10.13.37.0/24"]
  public_subnets  = ["10.13.0.0/24"]

  enable_nat_gateway = true

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

#Internet connectivity
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.team_vpc.id}"
  tags = {
    Name = "gw"
  }
}

#Create route table to push through internet gateway
resource "aws_route_table" "r" {
  vpc_id = "${aws_vpc.team_vpc.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }
  tags = {
    Name = "r"
  }
}

#Associate our public subnet with the route table, pushing it to the internet
resource "aws_route_table_association" "a" {
  subnet_id = "${aws_subnet.public_subnet.id}"
  route_table_id = "${aws_route_table.r.id}"
}

# Create a private key, 4096-bit RSA
resource "tls_private_key" "priv_key" {
  algorithm = "RSA"
  rsa_bits = "4096"
}
# Create a file for use with Windows users
resource "local_file" "private_key_pem" {
  content = tls_private_key.priv_key.private_key_pem
  filename = "../private_key.pem"
  file_permission = 0400
}
# Create a file for use with Linux/MacOS users
resource "local_file" "private_key_openssh" {
  content = tls_private_key.priv_key.private_key_openssh
  filename = "../private_key.key"
  file_permission = 0400
}

# Put the created key pair into the "key pairs" section, creating a public key from the private one
resource "aws_key_pair" "server_key" {
  key_name = "server"
  public_key = tls_private_key.priv_key.public_key_openssh
}

resource "aws_security_group" "bastion" {
  name = "Bastion"
  description = "Allow SSH and RDP"
  vpc_id = "${aws_vpc.team_vpc.id}"
# Ingress rule to allow SSH
  ingress {
    description = "SSH"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    # Allow only the BYUI network to SSH in
    cidr_blocks = ["157.201.0.0/16"]
  }
  ingress {
    description = "RDP"
    from_port = 3389
    to_port = 3389
    protocol = "tcp"
    cidr_blocks = ["157.201.0.0/16"]

  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "Bastion"
  }
}

resource "aws_security_group" "internal" {
  name = "Internal"
  description = "Allow all"
  vpc_id = "${aws_vpc.team_vpc.id}"
# Ingress rule to allow All
  ingress {
    description = "All allowed"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "Internal"
  }
}

# Create an EC2 instance running Ubuntu 22.04 LTS 
# Virginia East ami-007855ac798b5175e
# Oregon West ami-03f65b8614a860c29
# Amazon Linux 2 with MATE ami-005b11f8b84489615
# Windows Server 2022 Core Base ami-0fdeb49f47e90dd09
resource "aws_instance" "bastion_host" {
  ami = "ami-005b11f8b84489615"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.public_subnet.id}"
  key_name = aws_key_pair.server_key.key_name
  vpc_security_group_ids = [aws_security_group.bastion.id]
  associate_public_ip_address = "true"
  tags = {
    Name = "bastion_host"
  }
}

resource "aws_instance" "owasp-juice2023" {
  ami = "ami-0a70c7f569a1a4fd1"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.private_subnet.id}"
  key_name = aws_key_pair.server_key.key_name
  vpc_security_group_ids = [aws_security_group.internal.id]
  tags = {
    Name = "owasp-juice2023"
  }
  availability_zone = "us-east-1a"
}

resource "aws_instance" "owasp-juice2021" {
  ami = "ami-0cea98c1668042d67"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.private_subnet.id}"
  key_name = aws_key_pair.server_key.key_name
  vpc_security_group_ids = [aws_security_group.internal.id]
  tags = {
    Name = "owasp-juice2021"
  }
  availability_zone = "us-east-1a"
}
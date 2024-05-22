# https://developer-shubham-rasal.medium.com/aws-networking-using-terraform-cbbf28dcb124
# This script creates three AWS VMs - one a bastion/jumpbox host, an OWASP JuiceShop internal VM, and a NAT instance 
# A pem file is created if ran in cloudshell, which will allow ssh
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
}

# Create a VPC
resource "aws_vpc" "team_vpc" {
  cidr_block = "10.13.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = "true"
  tags = {
    Name = "team_vpc"
  }
}

#Create private subnet on VPC
resource "aws_subnet" "private_subnet" {
  vpc_id = "${aws_vpc.team_vpc.id}"
  cidr_block = "10.13.37.0/24"
  tags = {
    Name = "private_subnet"
  }
  availability_zone = "us-east-1a"
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

# Create an DC-6 image 
# Available on http://10.13.37.202 from the bastion host
resource "aws_instance" "dc-six" {
  ami = "ami-005b11f8b84489615"
  instance_type = "t2.micro"
  network_interface {
     network_interface_id = "${aws_network_interface.internalnictwo.id}"
     device_index = 0
  }
  tags = {
    Name = "dc-six"
  }
  availability_zone = "us-east-1a"
}

# Set the IP for the internal OWASP VM to be 10.13.37.202
resource "aws_network_interface" "internalnictwo" {
  subnet_id = "${aws_subnet.private_subnet.id}"
  private_ips = ["10.13.37.202"]
  security_groups = [aws_security_group.internal.id]
}



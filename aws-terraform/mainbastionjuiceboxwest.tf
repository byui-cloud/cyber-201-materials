# https://developer-shubham-rasal.medium.com/aws-networking-using-terraform-cbbf28dcb124
# Fix the nat: https://medium.com/nerd-for-tech/how-to-turn-an-amazon-linux-2023-ec2-into-a-nat-instance-4568dad1778f
# You may need to change enX0 on the instance to another NIC name
# This script creates three AWS VMs - one a bastion/jumpbox host, an OWASP JuiceShop internal VM, and a NAT instance 
# A pem file is created if run in cloudshell, which will allow ssh
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
  region = "us-west-2"
  shared_credentials_files = ["../credentials"]
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

#Create public subnet on VPC
resource "aws_subnet" "public_subnet" {
  vpc_id = "${aws_vpc.team_vpc.id}"
  cidr_block = "10.13.0.0/24"
  map_public_ip_on_launch = "true"
  tags = {
    Name = "public_subnet"
  }
  availability_zone = "us-west-2a"
}

#Create private subnet on VPC
resource "aws_subnet" "private_subnet" {
  vpc_id = "${aws_vpc.team_vpc.id}"
  cidr_block = "10.13.37.0/24"
  tags = {
    Name = "private_subnet"
  }
  availability_zone = "us-west-2a"
}

#Internet connectivity
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.team_vpc.id}"
  tags = {
    Name = "gw"
  }
}

#Create an elastic IP that the bastion host to stay the same
resource "aws_eip" "ipbastion" {
instance = aws_instance.bastion_host.id
  tags = {
    Name = "bastionEIP"
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

# Create a new route table for private subnet
resource "aws_route_table" "private_subnet_route_table" {
  vpc_id = aws_vpc.team_vpc.id

  tags = {
    Name = "private_subnet_route_table"
  }
}

#Associate our public subnet with the route table, pushing it to the internet
resource "aws_route_table_association" "a" {
  subnet_id = "${aws_subnet.public_subnet.id}"
  route_table_id = "${aws_route_table.r.id}"
}

# Associate the private subnet with the new route table
resource "aws_route_table_association" "private_subnet_association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_subnet_route_table.id
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
    # cidr_blocks = ["157.201.0.0/16"]
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "RDP"
    from_port = 3389
    to_port = 3389
    protocol = "tcp"
    # cidr_blocks = ["157.201.0.0/16"]
    cidr_blocks = ["0.0.0.0/0"]

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

# Security group for the NAT instance
resource "aws_security_group" "nat_security_group" {
  name        = "nat_security_group"
  description = "Security group for the NAT instance"
  vpc_id = "${aws_vpc.team_vpc.id}"
  # Allow inbound traffic from the private subnets
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.13.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
    tags = {
    Name = "nat_security"
  }
}


# Create an EC2 instance running Ubuntu 22.04 LTS 
# Virginia East ami-007855ac798b5175e
# Oregon West Amazon Linux 2023 ami-01e82af4e524a0aa3
# Oregon West Amazon Linux 2 Mate ami-0fe551f63319344fa
# Amazon Linux 2 with MATE ami-005b11f8b84489615
# Windows Server 2022 Core Base ami-0fdeb49f47e90dd09
resource "aws_instance" "bastion_host" {
  ami = "ami-0fe551f63319344fa"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.public_subnet.id}"
  key_name = aws_key_pair.server_key.key_name
  vpc_security_group_ids = [aws_security_group.bastion.id]
  associate_public_ip_address = "true"
  tags = {
    Name = "bastion_host"
  }
}

# Create an AWS Linux nat instance
resource "aws_instance" "owasp-nat" {
  ami = "ami-01e82af4e524a0aa3"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.public_subnet.id}"
  key_name = aws_key_pair.server_key.key_name
  vpc_security_group_ids = [aws_security_group.internal.id]
  # Disable source/destination checks for the NAT instance
  source_dest_check = false
  tags = {
    Name = "owasp-nat"
  }
  user_data = <<EOF
#!/bin/bash
sudo yum install -y iptables-services
sudo systemctl enable iptables.service
sudo systemctl start iptables.service
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
sudo iptables -t nat -A POSTROUTING -o enX0 -s 0.0.0.0/0 -j MASQUERADE
sudo /sbin/iptables -F FORWARD
sudo service iptables save
EOF
  availability_zone = "us-west-2a"
}

# Create an AWS Linux VM with OWASP Juiceshop app in a docker 
# Available on http://10.13.37.201 from the bastion host
resource "aws_instance" "owasp-juice" {
  ami = "ami-01e82af4e524a0aa3"
  instance_type = "t2.micro"
  network_interface {
     network_interface_id = "${aws_network_interface.internalnic.id}"
     device_index = 0
  }
  key_name = aws_key_pair.server_key.key_name
  tags = {
    Name = "owasp-juice"
  }
    user_data = <<EOF
#!/bin/bash
sudo yum install -y docker
sudo docker pull bkimminich/juice-shop:v12.8.1
sudo systemctl enable docker
sudo service docker start
sudo docker run --name naughty_keller -d --restart unless-stopped -p 80:3000 bkimminich/juice-shop:v12.8.1
  EOF
  availability_zone = "us-west-2a"
}
# This line below is the oldest docker version of juice shop
# sudo docker run --name naughty_keller -d --restart unless-stopped -p 80:3000 bkimminich/juice-shop:v7.0.2
# Set the IP for the internal OWASP VM to be 10.13.37.201
resource "aws_network_interface" "internalnic" {
  subnet_id = "${aws_subnet.private_subnet.id}"
  private_ips = ["10.13.37.201"]
  security_groups = [aws_security_group.internal.id]
}

# Add a default route to send non-local traffic through the NAT instance
resource "aws_route" "nat_route" {
  route_table_id         = aws_route_table.private_subnet_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  instance_id            = aws_instance.owasp-nat.id
}
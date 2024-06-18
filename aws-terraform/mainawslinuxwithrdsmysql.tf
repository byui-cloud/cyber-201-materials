# Find the IP using: aws ec2 describe-network-interfaces
# SSH into the instance after it is ready (replace the IP): ssh -i ../private_key.pem ec2-user@44.202.5.12
# To RDP, you need to set the password and create a new key on the ec2-user after you ssh in:
# sudo passwd ec2-user
# sudo openssl req -x509 -sha384 -newkey rsa:3072 -nodes -keyout /etc/xrdp/key.pem -out /etc/xrdp/cert.pem -days 365

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

# Create a private key, 4096-bit RSA
resource "tls_private_key" "priv_key" {
  algorithm = "RSA"
  rsa_bits = "4096"
}
# Create a security file to ssh in with
resource "local_file" "private_key_pem" {
  content = tls_private_key.priv_key.private_key_pem
  filename = "../private_key.pem"
  file_permission = 0400
}

# Create the key pair
resource "aws_key_pair" "server_key" {
  key_name = "server"
  public_key = tls_private_key.priv_key.public_key_openssh
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
  availability_zone = "us-east-1a"
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

# Create a new route table for private subnet
resource "aws_route_table" "private_subnet_route_table" {
  vpc_id = aws_vpc.team_vpc.id

  tags = {
    Name = "private_subnet_route_table"
  }
}

# Associate the route table with the public subnet
resource "aws_route_table_association" "public_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.r.id
}

# Allow SSH. CIDR blocks must be used or it will not work.
resource "aws_security_group" "byuisg" {
  name = "allow-ssh"
  description = "Allow SSH and RDP"
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
    # Allow only the BYUI network to SSH in
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
    Name = "allow_ssh"
  }
}

resource "aws_security_group" "rds_sg" {
  name = "rds_sg"
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.13.0.0/24"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create an EC2 instance Amazon Linux 2 with MATE ami-005b11f8b84489615
# Virginia ami-007855ac798b5175e
resource "aws_instance" "awslinx_hostrdp" {
  ami = "ami-005b11f8b84489615"
  instance_type = "t3.micro"
  key_name = aws_key_pair.server_key.key_name
  vpc_security_group_ids = [aws_security_group.byuisg.id]
  associate_public_ip_address = "true"
  tags = {
    Name = "awslinx_hostrdp"
  }
user_data = <<EOF
#!/bin/bash
sudo yum update -y
EOF  
}

# Create a mysql database in RDS
resource "aws_db_instance" "myinstance" {
  engine             = "mysql"
  identifier         = "myrdsinstance"
  allocated_storage  = 20
  engine_version     = "8.4"
  instance_class     = "db.t2.micro"
  username           = "admin"
  password           = "password"
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
}

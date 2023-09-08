# Find the IP using: aws ec2 describe-network-interfaces
# SSH into the instance after it is ready (replace the IP): ssh -i ../private_key.pem ec2-user@44.202.5.12

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

# Create an EC2 instance Microsoft Windows Server 2022 Base
resource "aws_instance" "winserver_host" {
  ami = "ami-0fc682b2a42e57ca2"
  instance_type = "t2.micro"
  key_name = aws_key_pair.server_key.key_name
  vpc_security_group_ids = [aws_security_group.byuisg.id]
  associate_public_ip_address = "true"
  tags = {
    Name = "winserver_host"
  }
}
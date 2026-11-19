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
  description = "Allow SSH and DCV"
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
    description = "DCV"
    from_port = 8443
    to_port = 8443
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
    description = "SSH"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    # Allow only the BYUI network to SSH in
    # cidr_blocks = ["157.201.0.0/16"]
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "DCV"
    from_port = 8443
    to_port = 8443
    protocol = "tcp"
    # cidr_blocks = ["157.201.0.0/16"]
    cidr_blocks = ["0.0.0.0/0"]

  }
    ingress {
    description = "All allowed"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["10.13.0.0/16"]
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
  # Forward traffic from instances in this VPC through the NAT instance.
  ingress {
    description = "Forwarded VPC traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
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

# Use AWS's regional public parameter so new instances always use the latest
# x86_64 Amazon Linux 2023 AMI in the configured region.
data "aws_ssm_parameter" "amazon_linux_2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_instance" "bastion_host" {
  ami = data.aws_ssm_parameter.amazon_linux_2023.value
  instance_type = "t3.medium"
  subnet_id = "${aws_subnet.public_subnet.id}"
  key_name = aws_key_pair.server_key.key_name
  vpc_security_group_ids = [aws_security_group.bastion.id]
  associate_public_ip_address = "true"
  tags = {
    Name = "bastion_host"
  }
  user_data = <<EOF
#!/bin/bash 
sudo /bin/su -c "echo '10.13.37.202 wordy' >> /etc/hosts"
sudo /bin/su -c "echo '10.13.37.201 owasp' >> /etc/hosts"
sudo dnf update -y
sudo dnf groupinstall "Desktop" -y
sudo systemctl set-default graphical.target

sudo rpm --import https://d1uj6qtbmh3dt5.cloudfront.net/NICE-GPG-KEY

wget https://d1uj6qtbmh3dt5.cloudfront.net/nice-dcv-amzn2023-x86_64.tgz

tar -xvzf nice-dcv-amzn2023-x86_64.tgz && cd nice-dcv-2026.0-25174-amzn2023-x86_64

sudo dnf install nice-dcv-server-2026.0.25174-1.amzn2023.x86_64.rpm

sudo dnf install nice-dcv-web-viewer-2026.0.25174-1.amzn2023.x86_64.rpm

sudo systemctl enable --now dcvserver

sudo dcv create-session --type=console --owner ec2-user console

sudo sed -i 's/^#WaylandEnable=false/WaylandEnable=false/' /etc/gdm/custom.conf
sudo systemctl restart gdm


sudo dnf install -y xorg-x11-drv-dummy

if [ -f /etc/X11/xorg.conf ]; then
  sudo cp -a /etc/X11/xorg.conf /etc/X11/xorg.conf.bak
fi


sudo tee /etc/X11/xorg.conf >/dev/null <<'EOF'
Section "Device"
    Identifier "DummyDevice"
    Driver "dummy"
    Option "UseEDID" "false"
    VideoRam 512000
EndSection

Section "Monitor"
    Identifier "DummyMonitor"
    HorizSync 5.0 - 1000.0
    VertRefresh 5.0 - 200.0
    Option "ReducedBlanking"
EndSection

Section "Screen"
    Identifier "DummyScreen"
    Device "DummyDevice"
    Monitor "DummyMonitor"
    DefaultDepth 24
    SubSection "Display"
        Viewport 0 0
        Depth 24
        Virtual 4096 2160
    EndSubSection
EndSection
EOF

sudo systemctl restart gdm
EOF
}

# Create an Amazon Linux 2023 NAT instance
resource "aws_instance" "owasp-nat" {
  ami = data.aws_ssm_parameter.amazon_linux_2023.value
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.public_subnet.id}"
  key_name = aws_key_pair.server_key.key_name
  vpc_security_group_ids = [aws_security_group.nat_security_group.id]
  # Disable source/destination checks for the NAT instance
  source_dest_check = false
  tags = {
    Name = "owasp-nat"
  }
  user_data = <<EOF
#!/bin/bash
set -euxo pipefail

dnf install -y iptables-nft
cat >/etc/sysctl.d/99-nat-instance.conf <<'SYSCTL'
net.ipv4.ip_forward = 1
SYSCTL
sysctl --system

cat >/usr/local/sbin/configure-nat.sh <<'NAT'
#!/bin/bash
set -euo pipefail
NIC="$(ip -o -4 route show default | awk 'NR == 1 {print $5}')"
iptables -F FORWARD
iptables -t nat -F POSTROUTING
iptables -P FORWARD ACCEPT
iptables -t nat -A POSTROUTING -o "$NIC" -j MASQUERADE
NAT
chmod 0755 /usr/local/sbin/configure-nat.sh

cat >/etc/systemd/system/configure-nat.service <<'UNIT'
[Unit]
Description=Configure IPv4 forwarding and NAT rules
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/configure-nat.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now configure-nat.service
EOF
  availability_zone = "us-east-1a"
}

# Create an Amazon Linux 2023 VM with OWASP Juice Shop in Docker 
# Available on http://10.13.37.201 from the bastion host
resource "aws_instance" "owasp-juice" {
  ami = data.aws_ssm_parameter.amazon_linux_2023.value
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
sudo dnf install -y docker
sudo docker pull bkimminich/juice-shop:v12.8.1
sudo systemctl enable docker
sudo service docker start
sudo docker run --name naughty_keller -d --restart unless-stopped -p 80:3000 bkimminich/juice-shop:v12.8.1
EOF
  availability_zone = "us-east-1a"
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

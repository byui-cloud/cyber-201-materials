# Ubuntu 22 AMI for add on to OWASP setup

# Create an EC2 instance running Ubuntu 22.04 LTS 
resource "aws_instance" "ubuntu_host" {
  ami = "ami-0cf2b4e024cdb6960"
  instance_type = "t2.micro"
  key_name = aws_key_pair.server_key.key_name
  network_interface {
     network_interface_id = "${aws_network_interface.internalnicthree.id}"
     device_index = 0
  }
  tags = {
    Name = "ubuntu_host"
  }
  availability_zone = "us-west-2a"
}



# Set the IP for the internal OWASP VM to be 10.13.37.203
resource "aws_network_interface" "internalnicthree" {
  subnet_id = "${aws_subnet.private_subnet.id}"
  private_ips = ["10.13.37.203"]
  security_groups = [aws_security_group.internal.id]
}

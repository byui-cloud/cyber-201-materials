# Create an EC2 instance Microsoft Windows Server 2022 Base
resource "aws_instance" "winserver_host" {
  ami = "ami-02dca614f074272a6"
  instance_type = "t2.micro"
  key_name = aws_key_pair.server_key.key_name
  network_interface {
     network_interface_id = "${aws_network_interface.internalnicfour.id}"
     device_index = 0
  }
  tags = {
    Name = "winserver_host"
  }
  availability_zone = "us-east-1a"
}

# Set the IP for the internal OWASP VM to be 10.13.37.204
resource "aws_network_interface" "internalnicfour" {
  subnet_id = "${aws_subnet.private_subnet.id}"
  private_ips = ["10.13.37.204"]
  security_groups = [aws_security_group.internal.id]
}

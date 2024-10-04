# Adds a Dc6 VM to the Bastion and Juice shop setup

# Create an DC-6 image 
# Available on http://10.13.37.202 from the bastion host
resource "aws_instance" "dc-six" {
  ami = "ami-00aae31f61b4654e2"
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

# Set the IP for the internal VM to be 10.13.37.202
resource "aws_network_interface" "internalnictwo" {
  subnet_id = "${aws_subnet.private_subnet.id}"
  private_ips = ["10.13.37.202"]
  security_groups = [aws_security_group.internal.id]
}



# Create an EC2 instance Microsoft Windows Server 2022 Base
resource "aws_instance" "winserver_host" {
  ami = "ami-02dca614f074272a6"
  instance_type = "t2.micro"
  key_name = aws_key_pair.server_key.key_name
  subnet_id = "${aws_subnet.public_subnet.id}"
  vpc_security_group_ids = [aws_security_group.bastion.id]  
  associate_public_ip_address = "true"
  tags = {
    Name = "winserver_host"
  }
  availability_zone = "us-east-1a"
}
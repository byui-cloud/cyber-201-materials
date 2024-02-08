#!/bin/bash

#Copy Juiceshop docker install script to internal VM
scp -i private_key.pem installjuiceshop.sh "ec2-user@10.13.37.201:/home/ec2-user/installjuiceshop.sh"
rm installjuiceshop.sh

#sets the RDP cert for remote desktop login
sudo passwd ec2-user
sudo openssl req -x509 -sha384 -newkey rsa:4096 -nodes -subj "/C=US/ST=ID/L=Rexburg/O=B/CN=www.example.com" -keyout /etc/xrdp/key.pem -out /etc/xrdp/cert.pem -days 365

# updates the server
sudo yum update -y

#connects to internal server
ssh -i private_key.pem "ec2-user@10.13.37.201"
#!/bin/bash

#sets the RDP cert for remote desktop login
sudo passwd ec2-user
sudo openssl req -x509 -sha384 -newkey rsa:3072 -nodes -keyout /etc/xrdp/key.pem -out /etc/xrdp/cert.pem -days 365

# updates the server
sudo yum update

#connects to internal server
ssh -i private_key.pem "ec2-user@10.13.37.201

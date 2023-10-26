#!/bin/bash
# Installs OWASP Juice Shop in a docker on port 80 and makes it auto start on reboot
sudo yum install -y docker
sudo docker pull bkimminich/juice-shop:v12.8.1
sudo systemctl enable docker
sudo service docker start
sudo docker run --name naughty_keller -d --restart unless-stopped -p 80:3000 bkimminich/juice-shop:v12.8.1
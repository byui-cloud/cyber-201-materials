#!/bin/bash

sudo yum install -y docker
sudo docker pull bkimminich/juice-shop
sudo systemctl enable docker
sudo service docker start
sudo docker run --name naughty_keller -d --restart unless-stopped -p 80:3000 bkimminich/juice-shop
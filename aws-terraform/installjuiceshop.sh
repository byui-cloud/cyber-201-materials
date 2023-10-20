#!/bin/bash

sudo yum install docker
sudo docker pull bkimminich/juice-shop
sudo systemctl enable docker
sudo service docker start
sudo docker run -d --restart unless-stopped -p 80:3000 bkimminich/juice-shop
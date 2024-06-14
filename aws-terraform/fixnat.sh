#!/bin/bash
# Adds IPtables rules needed for a NAT to have internet
# curl -O https://byui-cloud.github.io/cyber-201-materials/aws-terraform/fixnat.sh && chmod a+x fixnat.sh && ./fixnat.sh
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sudo sysctl -p /etc/sysctl.conf
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.d/custom-ip-forwarding.conf
sudo sysctl -p /etc/sysctl.d/custom-ip-forwarding.conf
sudo yum install iptables-services -y
sudo systemctl enable iptables
sudo systemctl start iptables
sudo /sbin/iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo /sbin/iptables -F FORWARD
sudo service iptables save
sudo amazon-linux-extras install firefox
#!/bin/bash
# Installs terraform, creates a folder, and deploys an EC2 AWS Linux Mate server
# Give execute permissions to this file and run it:
#  curl -O https://byui-cloud.github.io/cyber-201-materials/aws-terraform/build.sh && chmod a+x build.sh && ./build.sh
git clone https://github.com/tfutils/tfenv.git ~/.tfenv
mkdir ~/bin
ln -s ~/.tfenv/bin/* ~/bin/
tfenv install
tfenv use
mkdir byuieast
cd byuieast
curl -O https://byui-cloud.github.io/cyber-201-materials/aws-terraform/mainawslinux.tf
terraform init
terraform apply -auto-approve

read -n 1 -s -r -p $'\nPress any key to connect to the instance...'

# Next run the run.sh file to connect to the servers
# Give execute permissions to this file: chmod a+x run.sh
curl -O https://byui-cloud.github.io/cyber-201-materials/aws-terraform/run.sh && chmod a+x run.sh && ./run.sh

#!/bin/bash

mkdir newvm
cd newvm

read -p "Choose the type of servers to deploy:
1. DC6
2. Ubuntu Server
3. Windows Server
4. Provide a URL to another terraform .tf file
Enter the number of your choice: " tf_option

case $tf_option in
    1)
        tf_file="https://byui-cloud.github.io/cyber-201-materials/aws-terraform/maindc6added.tf"
        ;;
    2)
        tf_file="https://byui-cloud.github.io/cyber-201-materials/aws-terraform/mainubuntu.tf"
        ;;
    3)
        tf_file="https://byui-cloud.github.io/cyber-201-materials/aws-terraform/mainwindows.tf"
        ;;
    4)
        echo "Look at some .tf files listed here: https://github.com/byui-cloud/cyber-201-materials/tree/main/aws-terraform"
        echo "ex: https://byui-cloud.github.io/cyber-201-materials/aws-terraform/maindebian.tf (user: admin)"
        read -p "Enter the URL to a .tf file: " tf_file
        ;;
    *)
        echo "Error: Invalid option. Please select a valid option."
        exit 1
        ;;
esac

curl -O $tf_file
terraform init
terraform apply -auto-approve

cd ..

# Download the script to connect via ssh and give execute permissions to this file: chmod a+x run.sh
curl -O https://byui-cloud.github.io/cyber-201-materials/aws-terraform/run.sh && chmod a+x run.sh

# Download the file to remove the nat (It costs a lot per day for a NAT)
# The NAT allows you to download items from the internet on the internal juice shop
# curl -O https://byui-cloud.github.io/cyber-201-materials/aws-terraform/removenat.sh && chmod a+x removenat.sh

echo "Run ./terminate.sh when you are done to delete everything and save your budget." 
echo "If you have trouble connecting, wait a minute and try ./run.sh again."
read -n 1 -s -r -p $'\nPress any key to connect to the instance/VM (./run.sh) or CTRL + C to stop...'

# Next run the run.sh file to connect to the servers
./run.sh

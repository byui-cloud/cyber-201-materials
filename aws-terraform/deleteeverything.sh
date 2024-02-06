#!/bin/bash
# deletes the resources

rm build.sh
rm run.sh

cd byuieast
terraform destroy --auto-approve
rm -R ../byuieast/
# Run this if you have a leftover file
rm ../private_key.pem
rm ../private_key.key
rm ../terminate.sh
cd ..
# Remove if the 201 options was run
rm build201.sh
rm run201.sh

# Remove other files
rm connect.sh
rm installjuiceshop.sh
rm removenat.sh
rm update.sh
rm -fR bin/ 
rm deleteeverything.sh

# Terminate all instances
aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId]' --output text | \
while read -r instance_id; do
    aws ec2 terminate-instances --instance-ids "$instance_id"
done

# Remove all security groups except the default
default_group_id=$(aws ec2 describe-security-groups --filters Name=group-name,Values=default --query 'SecurityGroups[*].GroupId' --output text)
all_group_ids=$(aws ec2 describe-security-groups --query 'SecurityGroups[?GroupId!=`'$default_group_id'`].GroupId' --output text)

for group_id in $all_group_ids; do
    aws ec2 delete-security-group --group-id "$group_id"
done


# Remove all network interfaces
aws ec2 describe-network-interfaces --query 'NetworkInterfaces[*].[NetworkInterfaceId]' --output text | xargs -I {} aws ec2 delete-network-interface --network-interface-id {}

# Release all static IPs
aws ec2 describe-addresses --query 'Addresses[*].[AllocationId]' --output text | xargs -I {} aws ec2 release-address --allocation-id {}

# Delete all key pairs
aws ec2 delete-key-pair --key-name $(aws ec2 describe-key-pairs --query 'KeyPairs[*].[KeyName]' --output text)



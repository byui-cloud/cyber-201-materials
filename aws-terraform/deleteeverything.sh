#!/bin/bash
# deletes the resources
# Specify the directory path
directory_path="byuieast"

rm build.sh
rm run.sh

# Check if the directory exists
if [ -d "$directory" ]; then
    cd byuieast
    terraform destroy --auto-approve
    rm -R ../byuieast/
    # Run this if you have a leftover file
    rm ../terminate.sh
    cd ..
else
  echo "Directory does not exist."
fi

# Remove if the 201 options was run
rm -fR byuieast/
rm -f private_key.pem
rm -f private_key.key
rm -f build201.sh
rm -f run201.sh

# Remove other files
rm connect.sh
rm installjuiceshop.sh
rm removenat.sh
rm update.sh
rm -fR bin/ 
rm deleteeverything.sh

# Replace the instance names in the array with the actual names of your instances
instance_names=("bastion_host" "owasp-nat" "owasp-juice")

for instance_name in "${instance_names[@]}"; do
    # Terminate instances with the specified name directly
    aws ec2 terminate-instances --instance-ids $(aws ec2 describe-instances --filters "Name=tag:Name,Values=$instance_name" --query 'Reservations[].Instances[].InstanceId' --output text)

    echo "Termination request sent for instances with Name '$instance_name'."
done >/dev/null


# Remove 'Bastion' and 'Internal' security groups except the default

# Get the list of VPC IDs
vpc_ids=$(aws ec2 describe-vpcs --query 'Vpcs[*].VpcId' --output text)

# Check if VPC IDs are found
if [ -z "$vpc_ids" ]; then
  echo "Error: No VPCs found or unable to retrieve VPC IDs."
  exit 1
fi

# Loop through each VPC ID
for vpc_id in $vpc_ids; do
  echo "Processing VPC ID: $vpc_id"

  # Delete Security Group 'Bastion' if it exists
  bastion_group_id=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpc_id" "Name=group-name,Values=Bastion" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null)
  if [ -n "$bastion_group_id" ]; then
    echo "Deleting Security Group 'Bastion' in VPC $vpc_id"
    aws ec2 delete-security-group --group-id "$bastion_group_id"
    echo "Security Group 'Bastion' deleted successfully."
  else
    echo "Security Group 'Bastion' not found in VPC $vpc_id"
  fi

  # Delete Security Group 'Internal' if it exists
  internal_group_id=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpc_id" "Name=group-name,Values=Internal" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null)
  if [ -n "$internal_group_id" ]; then
    echo "Deleting Security Group 'Internal' in VPC $vpc_id"
    aws ec2 delete-security-group --group-id "$internal_group_id"
    echo "Security Group 'Internal' deleted successfully."
  else
    echo "Security Group 'Internal' not found in VPC $vpc_id"
  fi

done >/dev/null



# Remove all network interfaces
aws ec2 describe-network-interfaces --query 'NetworkInterfaces[*].[NetworkInterfaceId]' --output text | xargs -I {} aws ec2 delete-network-interface --network-interface-id {}

# Release all static IPs
aws ec2 describe-addresses --query 'Addresses[*].[AllocationId]' --output text | xargs -I {} aws ec2 release-address --allocation-id {}

# Delete all key pairs
aws ec2 delete-key-pair --key-name "server"

rm -f terraform.tfstate

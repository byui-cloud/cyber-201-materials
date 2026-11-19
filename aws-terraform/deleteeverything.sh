#!/bin/bash

# Confirm before either cleanup block or any AWS or Terraform command runs.
if [[ ! -t 0 ]]; then
  printf '%s\n' 'Cleanup cancelled: run this script in an interactive terminal.' >&2
  exit 1
fi

cat >&2 <<'WARNING'
WARNING: This is destructive. Use only in a dedicated, disposable lab account.

The AWS CLI portion attempts to delete network interfaces and release Elastic
IPs across the active AWS account and region, not just in the lab VPC. It also
attempts to terminate matching EC2 instances and delete matching security groups
and VPC resources. Unrelated workloads may be affected.

Terraform will attempt to destroy resources managed by the local byuieast/
workspace. This script also removes local Terraform state, SSH keys, and helper
files from the current directory; the original cleanup can remove state even
if Terraform destroy fails.
WARNING
printf 'Current directory: %s\n' "$PWD" >&2
printf 'Verify your AWS account, region, and Terraform workspace before continuing.\n' >&2
printf 'Type y and press Enter to proceed; anything else cancels [y/N]: ' >&2
if ! IFS= read -r answer || [[ "$answer" != y ]]; then
  printf '\n%s\n' 'Cleanup cancelled. No changes made.' >&2
  exit 0
fi

# deletes the resources
# curl -O https://byui-cloud.github.io/cyber-201-materials/aws-terraform/deleteeverything.sh && chmod a+x deleteeverything.sh
# Specify the directory path
directory="byuieast"

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
rm terminate.sh
rm addvm.sh
rm -fR newvm/ 

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

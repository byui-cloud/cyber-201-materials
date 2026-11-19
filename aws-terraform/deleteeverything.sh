#!/bin/bash
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

  # Delete Security Group 'nat_security' if it exists
  nat_security_group_id=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpc_id" "Name=group-name,Values=nat_security_group" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null)
  if [ -n "$nat_security_group_id" ]; then
    echo "Deleting Security Group 'nat_security' in VPC $vpc_id"
    aws ec2 delete-security-group --group-id "$nat_security_group_id"
    echo "Security Group 'nat_security' deleted successfully."
  else
    echo "Security Group 'nat_security' not found in VPC $vpc_id"
  fi

  # Delete Security Group 'rds_sg' if it exists
  rds_sg_id=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpc_id" "Name=group-name,Values=rds_sg" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null)
  if [ -n "$rds_sg_id" ]; then
    echo "Deleting Security Group 'rds_sg' in VPC $vpc_id"
    aws ec2 delete-security-group --group-id "$rds_sg_id"
    echo "Security Group 'rds_sg' deleted successfully."
  else
    echo "Security Group 'rds_sg' not found in VPC $vpc_id"
  fi

    # Delete Security Group 'allow-ssh' if it exists
  allow-ssh_id=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpc_id" "Name=group-name,Values=allow-ssh" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null)
  if [ -n "$allow-ssh_id" ]; then
    echo "Deleting Security Group 'allow-ssh' in VPC $vpc_id"
    aws ec2 delete-security-group --group-id "$allow-ssh_id"
    echo "Security Group 'allow-ssh' deleted successfully."
  else
    echo "Security Group 'allow-ssh' not found in VPC $vpc_id"
  fi
done



# Remove all network interfaces
aws ec2 describe-network-interfaces --query 'NetworkInterfaces[*].[NetworkInterfaceId]' --output text | xargs -I {} aws ec2 delete-network-interface --network-interface-id {}

# Release all static IPs
aws ec2 describe-addresses --query 'Addresses[*].[AllocationId]' --output text | xargs -I {} aws ec2 release-address --allocation-id {}

# Delete all key pairs
aws ec2 delete-key-pair --key-name "server"

# Delete the subnets
aws ec2 describe-subnets --filters "Name=vpc-id,Values=team_vpc" --query "Subnets[*].SubnetId" --output text | xargs -n 1 aws ec2 delete-subnet --subnet-id

#Delete the internet gateways
aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=team_vpc" --query "InternetGateways[*].InternetGatewayId" --output text | xargs -n 1 aws ec2 detach-internet-gateway --internet-gateway-id && aws ec2 delete-internet-gateway --internet-gateway-id

# Delete Route Tables:
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=team_vpc" --query "RouteTables[*].RouteTableId" --output text | xargs -n 1 aws ec2 delete-route-table --route-table-id

# Delete Security Groups
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=team_vpc" --query "SecurityGroups[*].GroupId" --output text | xargs -n 1 aws ec2 delete-security-group --group-id

# Delete network ACLS
aws ec2 describe-network-acls --filters "Name=vpc-id,Values=<Your-VPC-ID>" --query "NetworkAcls[*].NetworkAclId" --output text | xargs -n 1 aws ec2 delete-network-acl --network-acl-id

# Delete the VPC
aws ec2 delete-vpc --vpc-id $(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=team_vpc" --query "Vpcs[0].VpcId" --output text)


rm -f terraform.tfstate


#!/usr/bin/env bash
set -Eeuo pipefail

# VPCs are selected by their Name tag. Change this if your VPC uses another tag.
TARGET_VPC_NAME="team_vpc"

INSTANCE_NAMES=("bastion_host" "owasp-nat" "owasp-juice")
DIRECTORY="byuieast"

command -v aws >/dev/null 2>&1 || {
  echo "Error: AWS CLI is not installed."
  exit 1
}
aws sts get-caller-identity >/dev/null || {
  echo "Error: AWS CLI credentials are not working."
  exit 1
}

# Save the target VPC IDs before Terraform destroys anything.
mapfile -t vpc_ids < <(
  aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=$TARGET_VPC_NAME" \
    --query 'Vpcs[].VpcId' \
    --output text | tr '\t' '\n' | sed '/^$/d;/^None$/d'
)

if ((${#vpc_ids[@]} == 0)); then
  echo "No VPC tagged Name=$TARGET_VPC_NAME was found."
  echo "Terraform cleanup will still run if $DIRECTORY exists."
fi

# Destroy Terraform-managed resources first. Keep the directory if destroy fails.
if [[ -d "$DIRECTORY" ]]; then
  (
    cd "$DIRECTORY"
    terraform destroy --auto-approve
  )
  rm -rf -- "$DIRECTORY"
else
  echo "Terraform directory '$DIRECTORY' does not exist; skipping Terraform destroy."
fi

# Terminate only the named instances inside the target VPCs.
instance_ids=()
for vpc_id in "${vpc_ids[@]}"; do
  for instance_name in "${INSTANCE_NAMES[@]}"; do
    ids=$(aws ec2 describe-instances \
      --filters \
        "Name=vpc-id,Values=$vpc_id" \
        "Name=tag:Name,Values=$instance_name" \
        "Name=instance-state-name,Values=pending,running,stopping,stopped" \
      --query 'Reservations[].Instances[].InstanceId' \
      --output text)

    for id in $ids; do
      [[ -n "$id" && "$id" != "None" ]] && instance_ids+=("$id")
    done
  done
done

if ((${#instance_ids[@]} > 0)); then
  echo "Terminating instances: ${instance_ids[*]}"
  aws ec2 terminate-instances --instance-ids "${instance_ids[@]}" >/dev/null
  aws ec2 wait instance-terminated --instance-ids "${instance_ids[@]}"
fi

for vpc_id in "${vpc_ids[@]}"; do
  echo "Cleaning VPC $vpc_id"

  # Remove VPC endpoints before deleting their network interfaces.
  endpoint_ids=$(aws ec2 describe-vpc-endpoints \
    --filters "Name=vpc-id,Values=$vpc_id" \
    --query 'VpcEndpoints[].VpcEndpointId' \
    --output text)
  if [[ -n "$endpoint_ids" && "$endpoint_ids" != "None" ]]; then
    aws ec2 delete-vpc-endpoints \
      --vpc-endpoint-ids $endpoint_ids >/dev/null
  fi

  # Delete NAT gateways and release only the EIPs they used.
  nat_ids=$(aws ec2 describe-nat-gateways \
    --filter "Name=vpc-id,Values=$vpc_id" \
    --query 'NatGateways[?State!=`deleted`].NatGatewayId' \
    --output text)

  for nat_id in $nat_ids; do
    [[ -z "$nat_id" || "$nat_id" == "None" ]] && continue

    allocation_ids=$(aws ec2 describe-nat-gateways \
      --nat-gateway-ids "$nat_id" \
      --query 'NatGateways[].NatGatewayAddresses[].AllocationId' \
      --output text)

    aws ec2 delete-nat-gateway --nat-gateway-id "$nat_id" >/dev/null
    aws ec2 wait nat-gateway-deleted --nat-gateway-ids "$nat_id"

    for allocation_id in $allocation_ids; do
      [[ -n "$allocation_id" && "$allocation_id" != "None" ]] &&
        aws ec2 release-address --allocation-id "$allocation_id"
    done
  done

  # Delete available interfaces in this VPC only.
  eni_ids=$(aws ec2 describe-network-interfaces \
    --filters "Name=vpc-id,Values=$vpc_id" "Name=status,Values=available" \
    --query 'NetworkInterfaces[].NetworkInterfaceId' \
    --output text)
  for eni_id in $eni_ids; do
    [[ -n "$eni_id" && "$eni_id" != "None" ]] &&
      aws ec2 delete-network-interface --network-interface-id "$eni_id"
  done

  # Remove rules from non-default security groups so groups can be deleted.
  group_ids=$(aws ec2 describe-security-groups \
    --filters "Name=vpc-id,Values=$vpc_id" \
    --query 'SecurityGroups[?GroupName!=`default`].GroupId' \
    --output text)

  for group_id in $group_ids; do
    [[ -z "$group_id" || "$group_id" == "None" ]] && continue

    for is_egress in true false; do
      rule_ids=$(aws ec2 describe-security-group-rules \
        --filters "Name=group-id,Values=$group_id" \
        --query "SecurityGroupRules[?IsEgress==\`$is_egress\`].SecurityGroupRuleId" \
        --output text)

      if [[ -n "$rule_ids" && "$rule_ids" != "None" ]]; then
        if [[ "$is_egress" == true ]]; then
          aws ec2 revoke-security-group-egress \
            --group-id "$group_id" \
            --security-group-rule-ids $rule_ids
        else
          aws ec2 revoke-security-group-ingress \
            --group-id "$group_id" \
            --security-group-rule-ids $rule_ids
        fi
      fi
    done
  done

  # Delete every non-default group in this VPC, including Internal and Bastion.
  for group_id in $group_ids; do
    [[ -z "$group_id" || "$group_id" == "None" ]] && continue
    aws ec2 delete-security-group --group-id "$group_id"
  done

  # Delete subnets after instances and available network interfaces are gone.
  subnet_ids=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$vpc_id" \
    --query 'Subnets[].SubnetId' \
    --output text)
  for subnet_id in $subnet_ids; do
    [[ -n "$subnet_id" && "$subnet_id" != "None" ]] &&
      aws ec2 delete-subnet --subnet-id "$subnet_id"
  done

  # Delete non-main route tables and non-default network ACLs.
  route_table_ids=$(aws ec2 describe-route-tables \
    --filters "Name=vpc-id,Values=$vpc_id" \
    --query 'RouteTables[?length(Associations[?Main==`true`])==`0`].RouteTableId' \
    --output text)
  for route_table_id in $route_table_ids; do
    [[ -n "$route_table_id" && "$route_table_id" != "None" ]] &&
      aws ec2 delete-route-table --route-table-id "$route_table_id"
  done

  acl_ids=$(aws ec2 describe-network-acls \
    --filters "Name=vpc-id,Values=$vpc_id" \
    --query 'NetworkAcls[?IsDefault==`false`].NetworkAclId' \
    --output text)
  for acl_id in $acl_ids; do
    [[ -n "$acl_id" && "$acl_id" != "None" ]] &&
      aws ec2 delete-network-acl --network-acl-id "$acl_id"
  done

  # Detach and delete internet gateways attached to this VPC.
  igw_ids=$(aws ec2 describe-internet-gateways \
    --filters "Name=attachment.vpc-id,Values=$vpc_id" \
    --query 'InternetGateways[].InternetGatewayId' \
    --output text)
  for igw_id in $igw_ids; do
    [[ -z "$igw_id" || "$igw_id" == "None" ]] && continue
    aws ec2 detach-internet-gateway \
      --internet-gateway-id "$igw_id" \
      --vpc-id "$vpc_id"
    aws ec2 delete-internet-gateway --internet-gateway-id "$igw_id"
  done

  # Delete the VPC. AWS will report any remaining dependency instead of
  # deleting unrelated resources to work around it.
  aws ec2 delete-vpc --vpc-id "$vpc_id"
done

# Remove the local helper files used by this setup.
rm -f -- \
  build.sh run.sh private_key.pem private_key.key \
  build201.sh run201.sh connect.sh installjuiceshop.sh \
  removenat.sh update.sh deleteeverything.sh terminate.sh addvm.sh
rm -rf -- bin newvm
rm -f -- terraform.tfstate

echo "Cleanup complete."


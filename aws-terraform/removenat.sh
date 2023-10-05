#!/bin/bash

AWS_REGION="us-east-1"  # US East (N. Virginia)

# Find the NAT Gateway ID
NAT_GATEWAY_ID=$(aws ec2 describe-nat-gateways --region $AWS_REGION --query "NatGateways[0].NatGatewayId" --output text)

# Check if NAT Gateway ID is empty
if [ -z "$NAT_GATEWAY_ID" ]; then
  echo "No NAT Gateway found in region $AWS_REGION."
  exit 1
fi

echo "NAT Gateway ID found: $NAT_GATEWAY_ID"

# Delete the NAT Gateway
echo "Deleting NAT Gateway with ID $NAT_GATEWAY_ID..."
aws ec2 delete-nat-gateway --region $AWS_REGION --nat-gateway-id $NAT_GATEWAY_ID

# Check the deletion status
deletion_status=$?
if [ $deletion_status -eq 0 ]; then
  echo "NAT Gateway with ID $NAT_GATEWAY_ID deleted successfully."
else
  echo "Failed to delete NAT Gateway with ID $NAT_GATEWAY_ID."
  exit 1
fi

exit 0

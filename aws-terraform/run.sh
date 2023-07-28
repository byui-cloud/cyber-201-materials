#!/bin/bash

# Finds all EC2 instances and waits for the server to intialize
# Connects via ssh with the key and asks the users which instance to connect to

# Use describe-instances command to get all EC2 instances and the IP addresses
instances=$(aws ec2 describe-instances --query 'Reservations[].Instances[].[InstanceId, PublicIpAddress]' --output text)

if [[ -z "$instances" ]]; then
    echo "No EC2 instances found in your account."
    exit 1
fi

# Check the number of instances
num_instances=$(grep -c '' <<< "$instances")

if [[ $num_instances -eq 1 ]]; then
    # If there is only one instance, automatically select it for SSH
    selected_ip=$(awk '{print $2}' <<< "$instances")
else
    echo "Public IP addresses of all EC2 instances in your account:"

    # Print a list of instances with their public IP addresses
    i=1
    while read -r instance_id ip_address; do
        if [[ -z "$ip_address" ]]; then
            echo "$i. Instance ID: $instance_id - No public IP address"
        else
            echo "$i. Instance ID: $instance_id - Public IP address: $ip_address"
        fi
        i=$((i+1))
    done <<< "$instances"

    # Prompt user to choose an instance by number
    read -p "Enter the number of the instance you want to SSH into: " selected_num

    # Validate if the entered number is within the range of instances
    if ! [[ "$selected_num" =~ ^[1-$num_instances]$ ]]; then
        echo "Error: Invalid selection. Please enter a number from the list."
        exit 1
    fi

    # Get the selected IP address corresponding to the chosen number
    selected_ip=$(awk -v num="$selected_num" 'NR == num {print $2}' <<< "$instances")
fi

# Let the user pick the username to connect with
read -p "Choose the SSH username option:
1. ec2-user
2. ubuntu
3. Enter a custom username
Enter the number of your choice: " ssh_option

case $ssh_option in
    1)
        ssh_username="ec2-user"
        ;;
    2)
        ssh_username="ubuntu"
        ;;
    3)
        read -p "Enter the custom username: " ssh_username
        ;;
    *)
        echo "Error: Invalid option. Please select a valid SSH username option."
        exit 1
        ;;
esac

echo "Connecting to the instance with IP: $selected_ip..."
echo "Remember to turn everything off and delete it when you are done:"
echo "logout of ther VM server: 'logout' and then run: 'terraform destroy --auto-approve'"
echo "Delete the folder: 'rm -R byuieast' or run the terminate.sh script"
read -p "Pausing for 45 seconds for the server to intialize." -t 45

# Initiate SSH session to the selected instance
ssh -i ../private_key.pem "$ssh_username@$selected_ip"  # Replace 'ec2-user' with the appropriate SSH username for your EC2 instance




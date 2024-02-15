#!/bin/bash
# deletes the resources

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
rm build201.sh
rm run201.sh

# Remove other files
rm connect.sh
rm installjuiceshop.sh
rm removenat.sh
rm update.sh
rm -f private_key.pem
rm -f private_key.key
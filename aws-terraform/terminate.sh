#!/bin/bash
# deletes the resources

rm build.sh
rm run.sh

cd byuieast
terraform destroy --auto-approve
rm -R ../byuieast/
# Run this if you have a leftover file
# rm ../private_key.pem
rm ../terminate.sh
cd ..
# Remove if the 201 options was run
rm build201.sh
rm run201.sh
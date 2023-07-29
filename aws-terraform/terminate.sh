#!/bin/bash
# deletes the resources

rm build.sh
cd byuieast
terraform destroy --auto-approve
rm -R ../byuieast/
# Run this if you have a leftover file
# rm ../private_key.pem
rm ../terminate.sh
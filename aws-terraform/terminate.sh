#!/bin/bash
# deletes the resources

rm ../build.sh
cd byuieast
terraform destroy --auto-approve
rm -R ../byuieast/
rm ../private_key.pem
rm ../terminate.sh
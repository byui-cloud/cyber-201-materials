#!/bin/bash
# deletes the resources

cd byuieast
terraform destroy --auto-approve
rm -R ../byuieast/
rm ../private_key.pem

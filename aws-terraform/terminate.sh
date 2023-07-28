#!/bin/bash
# deletes the resources

terraform destroy --auto-approve
cd ..
rm -R "byuieast/*"
rm private_key.pem

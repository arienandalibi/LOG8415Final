#!/bin/bash

set -e  # stop script if any command fails
set -x  # print each command before executing

echo "switching directory"
cd ..
cd ./terraform

echo "Deleting terraform"
terraform.exe destroy -auto-approve

echo "Terraform destruction completed successfully"
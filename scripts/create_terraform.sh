cd ..
cd terraform

echo "Initializing terraform"
terraform.exe init

echo "Applying terraform changes"
terraform.exe apply -auto-approve

echo "Terraform completed successfully"

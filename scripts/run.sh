#!/bin/bash

set -e  # stop script if any command fails
set -x  # print each command before executing

# Only needed if images are not created or need to be updated
echo "Creating images"
# sh create_docker_workers.sh 
# sh create_docker_orchestrator.sh

sh create_terraform.sh  # create terraform IaC
sh create_docker_requests.sh # create docker image for requests
echo "Build success!"
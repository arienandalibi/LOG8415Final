#!/bin/bash

exec > /home/ubuntu/startup.log 2>&1

# update apt-get and install dependencies
sudo apt-get update
sudo apt-get install mysql-client


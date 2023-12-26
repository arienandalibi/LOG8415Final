#!/bin/bash

exec > /home/ubuntu/startup.log 2>&1

# update apt-get and install dependencies
sudo apt-get update
#sudo apt-get install -y gedit

# install MySQL Cluster
# common for workers too
sudo mkdir -p /opt/mysqlcluster/home
cd /opt/mysqlcluster/home
sudo wget http://dev.mysql.com/get/Downloads/MySQL-Cluster-7.2/mysql-cluster-gpl-7.2.1-linux2.6-x86_64.tar.gz
sudo tar xvf mysql-cluster-gpl-7.2.1-linux2.6-x86_64.tar.gz
ln -s mysql-cluster-gpl-7.2.1-linux2.6-x86_64 mysqlc
sudo sh -c "echo 'export MYSQLC_HOME=/opt/mysqlcluster/home/mysqlc' > /etc/profile.d/mysqlc.sh"
sudo sh -c "echo 'export PATH=$MYSQLC_HOME/bin:$PATH' >> /etc/profile.d/mysqlc.sh"
source /etc/profile.d/mysqlc.sh
sudo apt-get -y install libncurses5

# connect to host
sudo apt-get install -y awscli
export AWS_ACCESS_KEY_ID="${accessKey}"
export AWS_SECRET_ACCESS_KEY="${secretKey}"
export AWS_SESSION_TOKEN="${token}"
export AWS_DEFAULT_REGION="us-east-1"
sudo mkdir -p /opt/mysqlcluster/deploy/ndb_data
export manager_private_dns=$(aws ssm get-parameter --name "/myapp/manager_private_dns" --query "Parameter.Value" --output text)
echo $manager_private_dns > /home/ubuntu/info.log
echo "First try"
ndbd -c $manager_private_dns:1186
echo "Second try"
sudo /opt/mysqlcluster/home/mysqlc/bin/ndbd -c $manager_private_dns:1186

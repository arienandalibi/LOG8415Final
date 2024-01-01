#!/bin/bash

exec > /home/ubuntu/startup.log 2>&1

# update apt-get to install dependencies
sudo apt-get update

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

# get manager's private DNS from AWS's SSM
sudo apt-get install -y awscli
export AWS_ACCESS_KEY_ID="${accessKey}"
export AWS_SECRET_ACCESS_KEY="${secretKey}"
export AWS_SESSION_TOKEN="${token}"
export AWS_DEFAULT_REGION="us-east-1"


export manager_private_dns=$(aws ssm get-parameter --name "/myapp/manager_private_dns" --query "Parameter.Value" --output text)

sudo mkdir -p /opt/mysqlcluster/deploy
cd /opt/mysqlcluster/deploy
sudo mkdir conf
sudo mkdir mysqld_data
sudo mkdir ndb_data
sudo mkdir mysql-bin

# run the data node
sleep 10
sudo /opt/mysqlcluster/home/mysqlc/bin/ndbd --initial -c $manager_private_dns:1186

cd /home/ubuntu
sudo sh -c 'cat <<EOF >mysql_kp.pem
${mysql_kp}
EOF'

sudo chmod 600 /home/ubuntu/mysql_kp.pem

sudo ssh -fN -L 3306:localhost:3306 -i mysql_kp.pem -o StrictHostKeyChecking=no ubuntu@$manager_private_dns

# attempt to run server on the data node
# I got rid of this and changed it for the SSH Tunnel to the manager above
#
#sudo mkdir -p /opt/mysqlcluster/deploy
#cd /opt/mysqlcluster/deploy
#sudo mkdir ndb_data
#sudo mkdir conf
#sudo mkdir mysqld_data
#sudo mkdir mysql-bin
#cd conf
#sudo manager_private_dns="$manager_private_dns" sh -c 'cat <<EOF >my.cnf
#[mysqld]
#ndbcluster
#server-id=used terraform variable to substitute for 51 or 52 or 53
#bind-address=0.0.0.0
#datadir=/opt/mysqlcluster/deploy/mysqld_data
#basedir=/opt/mysqlcluster/home/mysqlc
#log-bin=/opt/mysqlcluster/deploy/mysql-bin/mysql-bin
#ndb-log-bin=ON
#binlog-format=STATEMENT
#port=3306
#ndb-connectstring=$manager_private_dns:1186
#
#[mysql_cluster]
#ndb-log-bin=ON
#ndb-connectstring=$manager_private_dns:1186
#EOF'
#
## initialize the database system files
#cd /opt/mysqlcluster/home/mysqlc
#sudo scripts/mysql_install_db --defaults-file=/opt/mysqlcluster/deploy/conf/my.cnf --datadir=/opt/mysqlcluster/deploy/mysqld_data
#
#
#
#
#sudo /opt/mysqlcluster/home/mysqlc/bin/mysqld --defaults-file=/opt/mysqlcluster/deploy/conf/my.cnf --user=root &
#sleep 15
#
#/opt/mysqlcluster/home/mysqlc/bin/mysqladmin -u root password 'root'
#
##create user for remote access, make sure this user only has read privileges
#sudo /opt/mysqlcluster/home/mysqlc/bin/mysql -h 127.0.0.1 -u root -p'root' <<EOF
#CREATE USER 'myapp'@'%' IDENTIFIED BY 'myapp';
#GRANT SELECT ON *.* TO 'myapp'@'%' IDENTIFIED BY 'myapp' WITH GRANT OPTION MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0;
#FLUSH PRIVILEGES;
#EOF
#
## add user to monitor SQL Server status by ProxySQL
#sudo /opt/mysqlcluster/home/mysqlc/bin/mysql -h 127.0.0.1 -u root -p'root' <<EOF
#CREATE USER 'monitor'@'%' IDENTIFIED BY 'monitorpassword';
#GRANT SELECT, PROCESS ON *.* TO 'monitor'@'%';
#FLUSH PRIVILEGES;
#EOF
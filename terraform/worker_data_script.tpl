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


export manager_private_dns=$(aws ssm get-parameter --name "/myapp/manager_private_dns" --query "Parameter.Value" --output text)

echo $manager_private_dns > /home/ubuntu/manager_dns.log

# attempt to run server on the data node
sudo mkdir -p /opt/mysqlcluster/deploy
cd /opt/mysqlcluster/deploy
sudo mkdir ndb_data
sudo mkdir conf
sudo mkdir mysqld_data
sudo mkdir mysql-bin
cd conf
sudo manager_private_dns="$manager_private_dns" sh -c 'cat <<EOF >my.cnf
[mysqld]
ndbcluster
server-id=${serverID}
bind-address=0.0.0.0
datadir=/opt/mysqlcluster/deploy/mysqld_data
basedir=/opt/mysqlcluster/home/mysqlc
log-bin=/opt/mysqlcluster/deploy/mysql-bin/mysql-bin
ndb-log-bin=ON
binlog-format=STATEMENT
port=3306
ndb-connectstring=$manager_private_dns:1186

[mysql_cluster]
ndb-log-bin=ON
ndb-connectstring=$manager_private_dns:1186
EOF'

#sudo sh -c 'cat <<EOF >config.ini
#[ndbd default]
#noofreplicas=1
#datadir=/opt/mysqlcluster/deploy/ndb_data
#
#[ndbd]
#hostname=$(curl http://169.254.169.254/latest/meta-data/local-hostname)
#nodeid=3
#
#[mysqld]
#nodeid=51
#EOF'

# initialize the database system files
cd /opt/mysqlcluster/home/mysqlc
sudo scripts/mysql_install_db --defaults-file=/opt/mysqlcluster/deploy/conf/my.cnf --datadir=/opt/mysqlcluster/deploy/mysqld_data

#sleep 10
#echo "Just show, no connect"
#sudo /opt/mysqlcluster/home/mysqlc/bin/ndb_mgm -e show
#echo "With connect statement"
#sudo /opt/mysqlcluster/home/mysqlc/bin/ndb_mgm -e "connect $manager_private_dns"

#sudo /opt/mysqlcluster/home/mysqlc/bin/mysql_upgrade --host $manager_private_dns -u myapp -p'myapp'  #--upgrade-system-tables

# run the data node
sleep 10
sudo /opt/mysqlcluster/home/mysqlc/bin/ndbd --initial -c $manager_private_dns:1186
sleep 10

sudo /opt/mysqlcluster/home/mysqlc/bin/mysqld --defaults-file=/opt/mysqlcluster/deploy/conf/my.cnf --user=root &
sleep 15

/opt/mysqlcluster/home/mysqlc/bin/mysqladmin -u root password 'root'

## start replication
#sudo /opt/mysqlcluster/home/mysqlc/bin/mysql -h 127.0.0.1 -u root -p'root' <<EOF
#CHANGE MASTER TO
#  MASTER_HOST='$manager_private_dns',
#  MASTER_PORT=3306,
#  MASTER_USER='repl_user',
#  MASTER_PASSWORD='password',
#  MASTER_LOG_FILE='',
#  MASTER_LOG_POS=4;
#EOF
#
##create user for replication
#sudo /opt/mysqlcluster/home/mysqlc/bin/mysql -h 127.0.0.1 -u root -p'root' <<EOF
#CREATE USER 'repl_user'@'%' IDENTIFIED BY 'password';
#GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'%';
#GRANT SUPER ON *.* TO 'repl_user'@'%';
#EOF


#create user for remote access, make sure this user only has read privileges
sudo /opt/mysqlcluster/home/mysqlc/bin/mysql -h 127.0.0.1 -u root -p'root' <<EOF
CREATE USER 'myapp'@'%' IDENTIFIED BY 'myapp';
GRANT ALL PRIVILEGES ON *.* TO 'myapp'@'%' IDENTIFIED BY 'myapp' WITH GRANT OPTION MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0;
FLUSH PRIVILEGES;
EOF

# add user to monitor SQL Server status by ProxySQL
sudo /opt/mysqlcluster/home/mysqlc/bin/mysql -h 127.0.0.1 -u root -p'root' <<EOF
CREATE USER 'monitor'@'%' IDENTIFIED BY 'monitorpassword';
GRANT SELECT, PROCESS ON *.* TO 'monitor'@'%';
FLUSH PRIVILEGES;
EOF
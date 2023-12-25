#!/bin/bash

exec > /home/ubuntu/startup.log 2>&1

# attempt to export variables
export worker1hostID=${worker1hostID}
export worker1privateDNS=${worker1privateDNS}
export worker1privateIP=${worker1privateIP}

#echo "Instance1 Private IP: $(aws_instance.worker1.private_ip)" > instance_info.txt
echo "Instance1 Private DNS: ${worker1privateDNS}" > /home/ubuntu/instance_info2.txt
#
## update apt-get and install dependencies
#sudo apt-get update
##sudo apt-get install -y gedit
#
## install MySQL Cluster
## common for workers too
#sudo mkdir -p /opt/mysqlcluster/home
#cd /opt/mysqlcluster/home
#sudo wget http://dev.mysql.com/get/Downloads/MySQL-Cluster-7.2/mysql-cluster-gpl-7.2.1-linux2.6-x86_64.tar.gz
#sudo tar xvf mysql-cluster-gpl-7.2.1-linux2.6-x86_64.tar.gz
#ln -s mysql-cluster-gpl-7.2.1-linux2.6-x86_64 mysqlc
#sudo sh -c "echo 'export MYSQLC_HOME=/opt/mysqlcluster/home/mysqlc' > /etc/profile.d/mysqlc.sh"
#sudo sh -c "echo 'export PATH=$MYSQLC_HOME/bin:$PATH' >> /etc/profile.d/mysqlc.sh"
#source /etc/profile.d/mysqlc.sh
#sudo apt-get -y install libncurses5
#
## specific to master
sudo mkdir -p /opt/mysqlcluster/deploy
cd /opt/mysqlcluster/deploy
sudo mkdir conf
sudo mkdir mysqld_data
sudo mkdir ndb_data
cd conf
sudo sh -c 'cat <<EOF >my.cnf
[mysqld]
ndbcluster
datadir=/opt/mysqlcluster/deploy/mysqld_data
basedir=/opt/mysqlcluster/home/mysqlc
port=3306
EOF'

sudo sh -c 'cat <<EOF >config.ini
[ndb_mgmd]
hostname=$(curl http://169.254.169.254/latest/meta-data/local-hostname)
datadir=/opt/mysqlcluster/deploy/ndb_data
nodeid=1

[ndbd default]
noofreplicas=1
datadir=/opt/mysqlcluster/deploy/ndb_data

[ndbd]
hostname=${worker1privateDNS}
nodeid=3

[mysqld]
nodeid=50
EOF'

# initialize the database
cd /opt/mysqlcluster/home/mysqlc
scripts/mysql_install_db –no-defaults –datadir=/opt/mysqlcluster/deploy/mysqld_data
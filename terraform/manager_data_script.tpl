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

# specific to master
sudo mkdir -p /opt/mysqlcluster/deploy
cd /opt/mysqlcluster/deploy
sudo mkdir conf
sudo mkdir mysqld_data
sudo mkdir ndb_data
sudo mkdir mysql-bin
cd conf
sudo sh -c 'cat <<EOF >my.cnf
[mysqld]
ndbcluster
server-id=50
bind-address=0.0.0.0
datadir=/opt/mysqlcluster/deploy/mysqld_data
basedir=/opt/mysqlcluster/home/mysqlc
log-bin=/opt/mysqlcluster/deploy/mysql-bin/mysql-bin
ndb-log-bin=ON
binlog-format=ROW
port=3306
ndb-connectstring=localhost:1186

[mysql_cluster]
ndb-connectstring=localhost:1186
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
TcpBind_INADDR_ANY=1
nodeid=3

[mysqld]
hostname=$(curl http://169.254.169.254/latest/meta-data/local-hostname)
nodeid=50

[mysqld]
hostname=${worker1privateDNS}
nodeid=51
EOF'

# initialize the database system files
cd /opt/mysqlcluster/home/mysqlc
sudo scripts/mysql_install_db --no-defaults --datadir=/opt/mysqlcluster/deploy/mysqld_data

# run the management service
sudo /opt/mysqlcluster/home/mysqlc/bin/ndb_mgmd -f /opt/mysqlcluster/deploy/conf/config.ini --initial --configdir=/opt/mysqlcluster/deploy/conf/

#start node server
sudo /opt/mysqlcluster/home/mysqlc/bin/mysqld --defaults-file=/opt/mysqlcluster/deploy/conf/my.cnf --user=root &

sleep 20
#set password so we can connect to it in script
/opt/mysqlcluster/home/mysqlc/bin/mysqladmin -u root password 'root'

#download sakila DB
sudo mkdir /tmp/sakila/
cd /tmp/sakila/
sudo wget https://downloads.mysql.com/docs/sakila-db.tar.gz
sudo tar xvf sakila-db.tar.gz

##create user responsible for replication
#sudo /opt/mysqlcluster/home/mysqlc/bin/mysql -h 127.0.0.1 -u root -p'root' <<EOF
#CREATE USER 'repl_user'@'%' IDENTIFIED BY 'password';
#GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'%';
#EOF
#
#sudo /opt/mysqlcluster/home/mysqlc/bin/mysql -h ${worker1privateDNS} -u repl_user -p'password' <<EOF
#START SLAVE;
#EOF

# change database engine from InnoDB to NDBCluster for proper replication
# SQL Node running on different servers can now access data
cd /tmp/sakila/sakila-db
sudo sed -i 's/InnoDB/NDBCLUSTER/g' sakila-schema.sql
#remove fulltext index as it isn't supported by NDBCLUSTER
sudo sed -i '/  FULLTEXT KEY idx_title_description (title,description)/d' sakila-schema.sql
sudo sed -i '203s/  PRIMARY KEY  (film_id),/  PRIMARY KEY  (film_id)/' sakila-schema.sql
sudo sed -i 's/) DEFAULT CHARSET=utf8mb4;/) ENGINE=NDBCLUSTER DEFAULT CHARSET=utf8mb4;/g' sakila-schema.sql

# add user to connect to database and add sakila DB
sudo /opt/mysqlcluster/home/mysqlc/bin/mysql -h 127.0.0.1 -u root -p'root' <<EOF
CREATE USER 'myapp'@'%' IDENTIFIED BY 'myapp';
GRANT ALL PRIVILEGES ON *.* TO 'myapp'@'%' IDENTIFIED BY 'myapp' WITH GRANT OPTION MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0;
FLUSH PRIVILEGES;
SOURCE /tmp/sakila/sakila-db/sakila-schema.sql
SOURCE /tmp/sakila/sakila-db/sakila-data.sql
EOF

# add user to monitor SQL Server status by ProxySQL
sudo /opt/mysqlcluster/home/mysqlc/bin/mysql -h 127.0.0.1 -u root -p'root' <<EOF
CREATE USER 'monitor'@'%' IDENTIFIED BY 'monitorpassword';
GRANT SELECT, PROCESS ON *.* TO 'monitor'@'%';
FLUSH PRIVILEGES;
EOF
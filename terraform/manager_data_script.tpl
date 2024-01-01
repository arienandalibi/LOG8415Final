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

# specific to master, set up configuration
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
bind-address=0.0.0.0
datadir=/opt/mysqlcluster/deploy/mysqld_data
basedir=/opt/mysqlcluster/home/mysqlc
port=3306
ndb-connectstring=localhost:1186
EOF'

sudo sh -c 'cat <<EOF >config.ini
[ndb_mgmd]
hostname=$(curl http://169.254.169.254/latest/meta-data/local-hostname)
datadir=/opt/mysqlcluster/deploy/ndb_data
nodeid=1

[ndbd default]
noofreplicas=3
datadir=/opt/mysqlcluster/deploy/ndb_data

[ndbd]
hostname=${worker1privateDNS}
nodeid=3

[ndbd]
hostname=${worker2privateDNS}
nodeid=4

[ndbd]
hostname=${worker3privateDNS}
nodeid=5

[mysqld]
nodeid=50
EOF'

# initialize the database system files
cd /opt/mysqlcluster/home/mysqlc
sudo scripts/mysql_install_db --no-defaults --datadir=/opt/mysqlcluster/deploy/mysqld_data

# run the management service
sudo /opt/mysqlcluster/home/mysqlc/bin/ndb_mgmd -f /opt/mysqlcluster/deploy/conf/config.ini --initial --configdir=/opt/mysqlcluster/deploy/conf/

# start SQL node server
sudo /opt/mysqlcluster/home/mysqlc/bin/mysqld --defaults-file=/opt/mysqlcluster/deploy/conf/my.cnf --user=root &

sleep 50
#set password so we can connect to it in script
/opt/mysqlcluster/home/mysqlc/bin/mysqladmin -u root password 'root'

#download sakila DB
sudo mkdir /tmp/sakila/
cd /tmp/sakila/
sudo wget https://downloads.mysql.com/docs/sakila-db.tar.gz
sudo tar xvf sakila-db.tar.gz

# add user to connect to database and add sakila DB
sudo /opt/mysqlcluster/home/mysqlc/bin/mysql -h 127.0.0.1 -u root -p'root' <<EOF
CREATE USER 'myapp'@'%' IDENTIFIED BY 'myapp';
CREATE USER 'myapp'@'localhost' IDENTIFIED BY 'myapp';
GRANT ALL PRIVILEGES ON *.* TO 'myapp'@'%' IDENTIFIED BY 'myapp' WITH GRANT OPTION MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0;
GRANT ALL PRIVILEGES ON *.* TO 'myapp'@'localhost' IDENTIFIED BY 'myapp' WITH GRANT OPTION MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0;
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

##run benchmarks
##read only
#sudo sysbench /usr/share/sysbench/oltp_read_only.lua --table-size=100000 --mysql-db=sakila --mysql-host=127.0.0.1 --mysql-user=root --mysql-password=root prepare
#sudo sysbench /usr/share/sysbench/oltp_read_only.lua --table-size=100000 --mysql-db=sakila --mysql-host=127.0.0.1 --mysql-user=root --mysql-password=root run
#sudo sysbench /usr/share/sysbench/oltp_read_only.lua --table-size=100000 --mysql-db=sakila --mysql-host=127.0.0.1 --mysql-user=root --mysql-password=root cleanup
#
##read only 5 threads
#sudo sysbench /usr/share/sysbench/oltp_read_only.lua --table-size=100000 --mysql-db=sakila --mysql-host=127.0.0.1 --mysql-user=root --mysql-password=root --threads=5 prepare
#sudo sysbench /usr/share/sysbench/oltp_read_only.lua --table-size=100000 --mysql-db=sakila --mysql-host=127.0.0.1 --mysql-user=root --mysql-password=root --threads=5 run
#sudo sysbench /usr/share/sysbench/oltp_read_only.lua --table-size=100000 --mysql-db=sakila --mysql-host=127.0.0.1 --mysql-user=root --mysql-password=root --threads=5 cleanup
#
##read/write
#sudo sysbench /usr/share/sysbench/oltp_read_write.lua --table-size=100000 --mysql-db=sakila --mysql-host=127.0.0.1 --mysql-user=root --mysql-password=root prepare
#sudo sysbench /usr/share/sysbench/oltp_read_write.lua --table-size=100000 --mysql-db=sakila --mysql-host=127.0.0.1 --mysql-user=root --mysql-password=root run
#sudo sysbench /usr/share/sysbench/oltp_read_write.lua --table-size=100000 --mysql-db=sakila --mysql-host=127.0.0.1 --mysql-user=root --mysql-password=root cleanup
#
##read/write 5 threads
#sudo sysbench /usr/share/sysbench/oltp_read_write.lua --table-size=100000 --mysql-db=sakila --mysql-host=127.0.0.1 --mysql-user=root --mysql-password=root --threads=5 prepare
#sudo sysbench /usr/share/sysbench/oltp_read_write.lua --table-size=100000 --mysql-db=sakila --mysql-host=127.0.0.1 --mysql-user=root --mysql-password=root --threads=5 run
#sudo sysbench /usr/share/sysbench/oltp_read_write.lua --table-size=100000 --mysql-db=sakila --mysql-host=127.0.0.1 --mysql-user=root --mysql-password=root --threads=5 cleanup
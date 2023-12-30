#!/bin/bash

exec > /home/ubuntu/startup.log 2>&1

# update apt-get and install dependencies
sudo apt-get update
sudo apt-get -y install mysql-server

# download and install sakila database
sudo mkdir /tmp/sakila/
cd /tmp/sakila/
sudo wget https://downloads.mysql.com/docs/sakila-db.tar.gz
sudo tar xvf sakila-db.tar.gz

# add user to connect to database and add sakila DB
sudo mysql -u root <<EOF
CREATE USER 'myapp'@'%' IDENTIFIED BY 'myapp';
GRANT ALL PRIVILEGES ON *.* TO 'myapp'@'%';
FLUSH PRIVILEGES;
SOURCE /tmp/sakila/sakila-db/sakila-schema.sql
SOURCE /tmp/sakila/sakila-db/sakila-data.sql
EOF

#if [ ${runSysbench} ]; then
## run sysbench benchmark
#sudo apt-get install -y sysbench
#
##read only
#sysbench /usr/share/sysbench/oltp_read_only.lua --table-size=100000 --mysql-db=sakila --mysql-user=myapp --mysql-password=myapp prepare
#sysbench /usr/share/sysbench/oltp_read_only.lua --table-size=100000 --mysql-db=sakila --mysql-user=myapp --mysql-password=myapp run
#sysbench /usr/share/sysbench/oltp_read_only.lua --table-size=100000 --mysql-db=sakila --mysql-user=myapp --mysql-password=myapp cleanup
#
##read only 5 threads
#sysbench /usr/share/sysbench/oltp_read_only.lua --table-size=100000 --mysql-db=sakila --mysql-user=myapp --mysql-password=myapp --threads=5 prepare
#sysbench /usr/share/sysbench/oltp_read_only.lua --table-size=100000 --mysql-db=sakila --mysql-user=myapp --mysql-password=myapp --threads=5 run
#sysbench /usr/share/sysbench/oltp_read_only.lua --table-size=100000 --mysql-db=sakila --mysql-user=myapp --mysql-password=myapp --threads=5 cleanup
#
##read/write
#sysbench /usr/share/sysbench/oltp_read_write.lua --table-size=100000 --mysql-db=sakila --mysql-user=myapp --mysql-password=myapp prepare
#sysbench /usr/share/sysbench/oltp_read_write.lua --table-size=100000 --mysql-db=sakila --mysql-user=myapp --mysql-password=myapp run
#sysbench /usr/share/sysbench/oltp_read_write.lua --table-size=100000 --mysql-db=sakila --mysql-user=myapp --mysql-password=myapp cleanup
#
##read/write 5 threads
#sysbench /usr/share/sysbench/oltp_read_write.lua --table-size=100000 --mysql-db=sakila --mysql-user=myapp --mysql-password=myapp --threads=5 prepare
#sysbench /usr/share/sysbench/oltp_read_write.lua --table-size=100000 --mysql-db=sakila --mysql-user=myapp --mysql-password=myapp --threads=5 run
#sysbench /usr/share/sysbench/oltp_read_write.lua --table-size=100000 --mysql-db=sakila --mysql-user=myapp --mysql-password=myapp --threads=5 cleanup
#
#fi
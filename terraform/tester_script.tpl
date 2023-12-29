#!/bin/bash

exec > /home/ubuntu/startup.log 2>&1

sudo apt-get update
sudo apt-get install -y mysql-client

# Connect to gatekeeper
cd /home/ubuntu
sudo sh -c 'cat <<EOF >mysql_kp.pem
${mysql_kp}
EOF'

sudo chmod 600 /home/ubuntu/mysql_kp.pem

sudo ssh -fN -L 3306:localhost:3306 -i mysql_kp.pem -o StrictHostKeyChecking=no ubuntu@${gatekeeperPrivateDNS}

sudo apt-get install -y sysbench

#run benchmarks
#read only
sudo sysbench /usr/share/sysbench/oltp_read_only.lua --table-size=100000 --mysql-db=sakila --mysql-host=127.0.0.1 --mysql-user=myapp --mysql-password=myapp prepare
sudo sysbench /usr/share/sysbench/oltp_read_only.lua --table-size=100000 --mysql-db=sakila --mysql-host=127.0.0.1 --mysql-user=myapp --mysql-password=myapp run
sudo sysbench /usr/share/sysbench/oltp_read_only.lua --table-size=100000 --mysql-db=sakila --mysql-host=127.0.0.1 --mysql-user=myapp --mysql-password=myapp cleanup

#read only 5 threads
sudo sysbench /usr/share/sysbench/oltp_read_only.lua --table-size=100000 --mysql-db=sakila --mysql-host=127.0.0.1 --mysql-user=myapp --mysql-password=myapp --threads=5 prepare
sudo sysbench /usr/share/sysbench/oltp_read_only.lua --table-size=100000 --mysql-db=sakila --mysql-host=127.0.0.1 --mysql-user=myapp --mysql-password=myapp --threads=5 run
sudo sysbench /usr/share/sysbench/oltp_read_only.lua --table-size=100000 --mysql-db=sakila --mysql-host=127.0.0.1 --mysql-user=myapp --mysql-password=myapp --threads=5 cleanup

#read/write
sudo sysbench /usr/share/sysbench/oltp_read_write.lua --table-size=100000 --mysql-db=sakila --mysql-host=127.0.0.1 --mysql-user=myapp --mysql-password=myapp prepare
sudo sysbench /usr/share/sysbench/oltp_read_write.lua --table-size=100000 --mysql-db=sakila --mysql-host=127.0.0.1 --mysql-user=myapp --mysql-password=myapp run
sudo sysbench /usr/share/sysbench/oltp_read_write.lua --table-size=100000 --mysql-db=sakila --mysql-host=127.0.0.1 --mysql-user=myapp --mysql-password=myapp cleanup

#read/write 5 threads
sudo sysbench /usr/share/sysbench/oltp_read_write.lua --table-size=100000 --mysql-db=sakila --mysql-host=127.0.0.1 --mysql-user=myapp --mysql-password=myapp --threads=5 prepare
sudo sysbench /usr/share/sysbench/oltp_read_write.lua --table-size=100000 --mysql-db=sakila --mysql-host=127.0.0.1 --mysql-user=myapp --mysql-password=myapp --threads=5 run
sudo sysbench /usr/share/sysbench/oltp_read_write.lua --table-size=100000 --mysql-db=sakila --mysql-host=127.0.0.1 --mysql-user=myapp --mysql-password=myapp --threads=5 cleanup
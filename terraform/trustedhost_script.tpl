#!/bin/bash

exec > /home/ubuntu/startup.log 2>&1

#sudo apt-get update
#sudo apt-get install -y mysql-client

cd /home/ubuntu
sudo sh -c 'cat <<EOF >mysql_kp.pem
${mysql_kp}
EOF'

sudo chmod 600 /home/ubuntu/mysql_kp.pem
sleep 10
sudo ssh -fN -L 3306:localhost:6033 -i mysql_kp.pem -o StrictHostKeyChecking=no ubuntu@${proxyPrivateDNS}

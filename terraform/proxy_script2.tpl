#!/bin/bash

exec > /home/ubuntu/startup.log 2>&1

export DEBIAN_FRONTEND=noninteractive

# allows us to interact with the configuration of our proxy
sudo apt-get update
sudo apt-get install -y mysql-client
sudo apt-get install -y awscli
export AWS_ACCESS_KEY_ID="${accessKey}"
export AWS_SECRET_ACCESS_KEY="${secretKey}"
export AWS_SESSION_TOKEN="${token}"
export AWS_DEFAULT_REGION="us-east-1"


export manager_private_dns=$(aws ssm get-parameter --name "/myapp/manager_private_dns" --query "Parameter.Value" --output text)

echo $manager_private_dns > /home/ubuntu/manager_dns.log

cd /home/ubuntu/
echo '${python_file}' | base64 -d > proxy_telnet.py

sudo tee mysql_kp.pem <<EOF
${mysql_kp}
EOF

sudo chmod 600 /home/ubuntu/mysql_kp.pem


sudo ssh -fN -L 3307:localhost:3306 -i mysql_kp.pem -o StrictHostKeyChecking=no ubuntu@${worker1privateDNS}
sudo ssh -fN -L 3308:localhost:3306 -i mysql_kp.pem -o StrictHostKeyChecking=no ubuntu@${worker2privateDNS}
sudo ssh -fN -L 3309:localhost:3306 -i mysql_kp.pem -o StrictHostKeyChecking=no ubuntu@${worker3privateDNS}

sudo apt-get install -y python3
sudo apt-get install -y python3-pip
sudo pip3 install mysql-connector-python

sleep 40

sudo python3 /home/ubuntu/proxy_telnet.py > python_output.log &

# sudo ssh -i mysql_kp.pem -o StrictHostKeyChecking=no ubuntu@
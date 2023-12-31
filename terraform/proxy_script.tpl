#!/bin/bash

exec > /home/ubuntu/startup.log 2>&1

sudo wget -O - 'https://repo.proxysql.com/ProxySQL/proxysql-2.5.x/repo_pub_key' | sudo apt-key add -
sudo echo deb https://repo.proxysql.com/ProxySQL/proxysql-2.5.x/$(lsb_release -sc)/ ./ | sudo tee /etc/apt/sources.list.d/proxysql.list

# install and start service so we can connect to it
sudo apt-get update
sudo apt-get install -y proxysql
sudo service proxysql start

# allows us to interact with the configuration of proxysql
sudo apt-get install -y mysql-client
sudo apt-get install -y awscli
export AWS_ACCESS_KEY_ID="${accessKey}"
export AWS_SECRET_ACCESS_KEY="${secretKey}"
export AWS_SESSION_TOKEN="${token}"
export AWS_DEFAULT_REGION="us-east-1"


export manager_private_dns=$(aws ssm get-parameter --name "/myapp/manager_private_dns" --query "Parameter.Value" --output text)

#echo $manager_private_dns > /home/ubuntu/manager_dns.log

# create script to ping servers and update ProxySQL rules accordingly
# Since the script will only be running once per second, I will update weights
# To distribute traffic evenly based on the ping
# Otherwise, a surge in traffic will overload one server at a time, switching every second
# This is useful while we're running sysbench benchmarks, which sends a lot of traffic at once.
# However, if we want to only send traffic to the server with the lowest ping,
# we can change our for loop which builds the command variable to check if we're dealing with the fastest server or not.
# If we're dealing with the fastest server, we add to the command to:
# WHEN port = '$port' THEN 'ONLINE'
# and if we're not dealing with the fastest server, we add to the command:
# WHEN port = '$port' THEN 'OFFLINE_SOFT'
# By setting a server's status as 'OFFLINE_SOFT', we're telling ProxySQL not to establish any new connections with it,
# while safely concluding any connections which have already been established.
# The script is provided as "strict_ping_script.sh", which can be substituted below using
# a provisioner "file" construct in terraform to put the script in the instance's home directory
# I did this before I found out I could do that

cd /home/ubuntu/
sudo manager_private_dns=$manager_private_dns sh -c 'cat <<EOF >ping_script.sh
#!/bin/bash

#list of servers
servers=($manager_private_dns ${worker1privateDNS} ${worker2privateDNS} ${worker3privateDNS})

# Ping and see which one responds fastest
minPing=21474836
maxPing=0
fastest=" "
pings=()
for server in "\$${servers[@]}"; do
    result=\$(ping -c 1 "\$server" | grep "time=" | awk -F'\''='\'' '\''{print \$4}'\'' | cut -d'\'' '\'' -f1)
    ping=\$((10#\$${result//"."}))
    pings+=(\$((\$ping * 100)))
    if [ "\$ping" -lt "\$minPing" ]; then
      minPing=\$ping
      fastest=\$server
    fi
    if [ "\$ping" -gt "\$maxPing" ]; then
      maxPing=\$ping
    fi
done

command="UPDATE mysql_servers SET weight = CASE "
i=0
port=3306
for server in "\$${servers[@]}"; do
    command+="WHEN port = \$port THEN \$((\$${pings[i]} / \$maxPing)) "
    ((i++))
    ((port++))
done
command+="END;"
mysql -u admin -padmin -h 127.0.0.1 -P 6032 <<LOL
\$command
LOL
EOF'

sudo tee mysql_kp.pem <<EOF
${mysql_kp}
EOF

sudo chmod 600 /home/ubuntu/mysql_kp.pem
sudo chmod +x ping_script.sh

sudo ssh -fN -L 3307:localhost:3306 -i mysql_kp.pem -o StrictHostKeyChecking=no ubuntu@${worker1privateDNS}
sudo ssh -fN -L 3308:localhost:3306 -i mysql_kp.pem -o StrictHostKeyChecking=no ubuntu@${worker2privateDNS}
sudo ssh -fN -L 3309:localhost:3306 -i mysql_kp.pem -o StrictHostKeyChecking=no ubuntu@${worker3privateDNS}


mysql -u admin -padmin -h 127.0.0.1 -P 6032 <<EOF
UPDATE global_variables SET variable_value='monitor' WHERE variable_name='mysql-monitor_username';
UPDATE global_variables SET variable_value='monitorpassword' WHERE variable_name='mysql-monitor_password';
LOAD MYSQL VARIABLES TO RUNTIME;
SAVE MYSQL VARIABLES TO DISK;

INSERT INTO mysql_servers (hostname, port, hostgroup_id) VALUES ('$manager_private_dns', 3306, 0);
INSERT INTO mysql_servers (hostname, port, hostgroup_id) VALUES ('127.0.0.1', 3307, 1);
INSERT INTO mysql_servers (hostname, port, hostgroup_id) VALUES ('127.0.0.1', 3308, 1);
INSERT INTO mysql_servers (hostname, port, hostgroup_id) VALUES ('127.0.0.1', 3309, 1);
LOAD MYSQL SERVERS TO RUNTIME;
SAVE MYSQL SERVERS TO DISK;

INSERT INTO mysql_users(username, password, active, default_hostgroup) VALUES ('myapp', 'myapp', 1, 0);
LOAD MYSQL USERS TO RUNTIME;
SAVE MYSQL USERS TO DISK;

SET mysql-eventslog_default_log=1;
SET mysql-eventslog_filename='queries.log';
SET mysql-eventslog_format=2;
LOAD MYSQL VARIABLES TO RUNTIME;
SAVE MYSQL VARIABLES TO DISK;

INSERT INTO mysql_query_rules (rule_id, active, match_digest, destination_hostgroup, log, apply) VALUES (1, 1, '^SELECT .*', 1, 1, 1),
(2, 1, '^(INSERT|UPDATE|DELETE) .*', 0, 1, 1);
LOAD MYSQL QUERY RULES TO RUNTIME;
SAVE MYSQL QUERY RULES TO DISK;
EOF

## If we want to use the direct hit pattern, instead of running the script, we change the rule to send all traffic to the master node
#mysql -u admin -padmin -h 127.0.0.1 -P 6032 <<EOF
#DELETE FROM mysql_query_rules;
#INSERT INTO mysql_query_rules (rule_id, active, match_digest, destination_hostgroup, log, apply) VALUES (1, 1, '^.*$', 0, 1, 1);
#LOAD MYSQL QUERY RULES TO RUNTIME;
#SAVE MYSQL QUERY RULES TO DISK;
#EOF

# If we want to use the random pattern, we can simply not do anything, since ProxySQL will automatically assign
# Weights of 1 to each server, meaning each server will be used the same amount, and requests will be essentially random.
# Otherwise, we can use the following script:
##!/bin/bash
#servers=($manager_private_dns ${worker1privateDNS} ${worker2privateDNS} ${worker3privateDNS})
#command="UPDATE mysql_servers SET status = CASE "
#i=0
#random=$((RANDOM % 4))
#for server in "$${servers[@]}"; do
#    if [ $i -eq $random ]; then
#      command+="WHEN hostname = '$server' THEN 'ONLINE' "
#    else
#      command+="WHEN hostname = '$server' THEN 'OFFLINE_SOFT' "
#    fi
#    ((i++))
#done
#command+="END;"
#mysql -u admin -padmin -h 127.0.0.1 -P 6032 <<LOL
#\$command
#LOL


# If we want to use the customized proxy pattern, we run our script from above which pings the servers and updates our preferred server
# or else, we can change ping_script.sh for the script right above to send to random servers
nohup bash -c "while true; do /home/ubuntu/ping_script.sh; sleep 1; done" > /dev/null 2>&1 &

# proxy script
# pip install mysql-connector-python
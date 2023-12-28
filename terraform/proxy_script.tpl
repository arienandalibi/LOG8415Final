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

echo $manager_private_dns > /home/ubuntu/manager_dns.log

# create script to ping servers and update ProxySQL rules accordingly
# Since the script will only be running once per second, I will update weights
# To distribute traffic evenly based on the ping
# Otherwise, a surge in traffic will overload one server at a time, switching every second
cd /home/ubuntu/
sudo manager_private_dns=$manager_private_dns sh -c 'cat <<EOF >ping_script.sh
#!/bin/bash

#list of servers
servers=($manager_private_dns ${worker1privateDNS})
#servers=(ip-172-31-24-112.ec2.internal ip-172-31-24-20.ec2.internal)


# Ping and see which one responds fastest
minPing=21474836
maxPing=0
fastest=" "
pings=()
for server in "\${servers[@]}"; do
    result=\$(ping -c 1 "\$server" | grep "time=" | awk -F'\''='\'' '\''{print \$4}'\'' | cut -d'\'' '\'' -f1)
    ping=\$((10#\${result//"."}))
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
for server in "\${servers[@]}"; do
    command+="WHEN hostname = \"\$server\" THEN \$((\${pings[i]} / \$maxPing)) "
    ((i++))
done
command+="END;"
mysql -u admin -padmin -h 127.0.0.1 -P 6032 <<LOL
\$command
LOL
EOF'

sudo chmod +x ping_script.sh


mysql -u admin -padmin -h 127.0.0.1 -P 6032 <<EOF
UPDATE global_variables SET variable_value='monitor' WHERE variable_name='mysql-monitor_username';
UPDATE global_variables SET variable_value='monitorpassword' WHERE variable_name='mysql-monitor_password';
LOAD MYSQL VARIABLES TO RUNTIME;
SAVE MYSQL VARIABLES TO DISK;

INSERT INTO mysql_servers (hostname, port, hostgroup_id) VALUES ('$manager_private_dns', 3306, 0);
INSERT INTO mysql_servers (hostname, port, hostgroup_id) VALUES ('${worker1privateDNS}', 3306, 1);
LOAD MYSQL SERVERS TO RUNTIME;
SAVE MYSQL SERVERS TO DISK;

INSERT INTO mysql_users(username, password, active, default_hostgroup) VALUES ('myapp', 'myapp', 1, 0);
LOAD MYSQL USERS TO RUNTIME;
SAVE MYSQL USERS TO DISK;

INSERT INTO mysql_query_rules (rule_id, active, match_digest, destination_hostgroup, apply) VALUES (1,1,'^SELECT.*FOR UPDATE',0,1),
(2, 1, '^SELECT .*', 1, 1),
(3, 1, '^(INSERT|UPDATE|DELETE) .*', 0, 1);
LOAD MYSQL QUERY RULES TO RUNTIME;
SAVE MYSQL QUERY RULES TO DISK;
EOF

# mysql_server_ping_log for ping information
nohup bash -c "while true; do /home/ubuntu/ping_script.sh; sleep 1; done" > /dev/null 2>&1 &
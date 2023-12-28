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

mysql -u admin -padmin -h 127.0.0.1 -P 6032 --prompt='ProxySQLAdmin> ' <<EOF
UPDATE global_variables SET variable_value='monitor' WHERE variable_name='mysql-monitor_username';
UPDATE global_variables SET variable_value='monitorpassword' WHERE variable_name='mysql-monitor_password';
LOAD MYSQL VARIABLES TO RUNTIME;
SAVE MYSQL VARIABLES TO DISK;


INSERT INTO mysql_servers (hostname, port, hostgroup_id) VALUES ('$manager_private_dns', 3306, 0);
INSERT INTO mysql_servers (hostname, port, hostgroup_id) VALUES ('${worker1privateDNS}', 3306, 1);
LOAD MYSQL SERVERS TO RUNTIME;
SAVE MYSQL SERVERS TO DISK;


EOF


# mysql_server_ping_log for ping information

# config file
##file proxysql.cfg
#
#########################################################################################
## This config file is parsed using libconfig , and its grammar is described in:
## http://www.hyperrealm.com/libconfig/libconfig_manual.html#Configuration-File-Grammar
## Grammar is also copied at the end of this file
#########################################################################################
#
#########################################################################################
## IMPORTANT INFORMATION REGARDING THIS CONFIGURATION FILE:
#########################################################################################
## On startup, ProxySQL reads its config file (if present) to determine its datadir.
## What happens next depends on if the database file (disk) is present in the defined
## datadir (i.e. "/var/lib/proxysql/proxysql.db").
##
## If the database file is found, ProxySQL initializes its in-memory configuration from
## the persisted on-disk database. So, disk configuration gets loaded into memory and
## then propagated towards the runtime configuration.
##
## If the database file is not found and a config file exists, the config file is parsed
## and its content is loaded into the in-memory database, to then be both saved on-disk
## database and loaded at runtime.
##
## IMPORTANT: If a database file is found, the config file is NOT parsed. In this case
##            ProxySQL initializes its in-memory configuration from the persisted on-disk
##            database ONLY. In other words, the configuration found in the proxysql.cnf
##            file is only used to initial the on-disk database read on the first startup.
##
## In order to FORCE a re-initialise of the on-disk database from the configuration file
## the ProxySQL service should be started with "systemctl start proxysql-initial".
##
#########################################################################################
#
#datadir="/var/lib/proxysql"
#errorlog="/var/lib/proxysql/proxysql.log"
#
#admin_variables=
#{
#        admin_credentials="admin:admin"
##       mysql_ifaces="127.0.0.1:6032;/tmp/proxysql_admin.sock"
#        mysql_ifaces="0.0.0.0:6032"
##       refresh_interval=2000
##       debug=true
#}
#
#mysql_variables=
#{
#        threads=4
#        max_connections=2048
#        default_query_delay=0
#        default_query_timeout=36000000
#        have_compress=true
#        poll_timeout=2000
##       interfaces="0.0.0.0:6033;/tmp/proxysql.sock"
#        interfaces="0.0.0.0:6033"
#        default_schema="information_schema"
#        stacksize=1048576
#        server_version="5.5.30"
#        connect_timeout_server=3000
## make sure to configure monitor username and password
## https://github.com/sysown/proxysql/wiki/Global-variables#mysql-monitor_username-mysql-monitor_password
#        monitor_username="monitor"
#        monitor_password="monitor"
#        monitor_history=600000
#        monitor_connect_interval=60000
#        monitor_ping_interval=10000
#        monitor_read_only_interval=1500
#        monitor_read_only_timeout=500
#        ping_interval_server_msec=120000
#        ping_timeout_server=500
#        commands_stats=true
#        sessions_sort=true
#        connect_retries_on_failure=10
#}
#
#
## defines all the MySQL servers
#mysql_servers =
#(
##       {
##               address = "127.0.0.1" # no default, required . If port is 0 , address is interpred as a Unix Socket Domain
##               port = 3306           # no default, required . If port is 0 , address is interpred as a Unix Socket Domain
##               hostgroup = 0           # no default, required
##               status = "ONLINE"     # default: ONLINE
##               weight = 1            # default: 1
##               compression = 0       # default: 0
##   max_replication_lag = 10  # default 0 . If greater than 0 and replication lag passes such threshold, the server is shunned
##       },
##       {
##               address = "/var/lib/mysql/mysql.sock"
##               port = 0
##               hostgroup = 0
##       },
##       {
##               address="127.0.0.1"
##               port=21891
##               hostgroup=0
##               max_connections=200
##       },
##       { address="127.0.0.2" , port=3306 , hostgroup=0, max_connections=5 },
##       { address="127.0.0.1" , port=21892 , hostgroup=1 },
##       { address="127.0.0.1" , port=21893 , hostgroup=1 }
##       { address="127.0.0.2" , port=3306 , hostgroup=1 },
##       { address="127.0.0.3" , port=3306 , hostgroup=1 },
##       { address="127.0.0.4" , port=3306 , hostgroup=1 },
##       { address="/var/lib/mysql/mysql.sock" , port=0 , hostgroup=1 }
#)
#
#
## defines all the MySQL users
#mysql_users:
#(
##       {
##               username = "username" # no default , required
##               password = "password" # default: ''
##               default_hostgroup = 0 # default: 0
##               active = 1            # default: 1
##       },
##       {
##               username = "root"
##               password = ""
##               default_hostgroup = 0
##               max_connections=1000
##               default_schema="test"
##               active = 1
##       },
##       { username = "user1" , password = "password" , default_hostgroup = 0 , active = 0 }
#)
#
#
#
##defines MySQL Query Rules
#mysql_query_rules:
#(
##       {
##               rule_id=1
##               active=1
##               match_pattern="^SELECT .* FOR UPDATE$"
##               destination_hostgroup=0
##               apply=1
##       },
##       {
##               rule_id=2
##               active=1
##               match_pattern="^SELECT"
##               destination_hostgroup=1
##               apply=1
##       }
#)
#
#scheduler=
#(
##  {
##    id=1
##    active=0
##    interval_ms=10000
##    filename="/var/lib/proxysql/proxysql_galera_checker.sh"
##    arg1="0"
##    arg2="0"
##    arg3="0"
##    arg4="1"
##    arg5="/var/lib/proxysql/proxysql_galera_checker.log"
##  }
#)
#
#
#mysql_replication_hostgroups=
#(
##        {
##                writer_hostgroup=30
##                reader_hostgroup=40
##                comment="test repl 1"
##       },
##       {
##                writer_hostgroup=50
##                reader_hostgroup=60
##                comment="test repl 2"
##        }
#)
#
#
#
#
## http://www.hyperrealm.com/libconfig/libconfig_manual.html#Configuration-File-Grammar
##
## Below is the BNF grammar for configuration files. Comments and include directives are not part of the grammar, so they are not included here.
##
## configuration = setting-list | empty
##
## setting-list = setting | setting-list setting
##
## setting = name (":" | "=") value (";" | "," | empty)
##
## value = scalar-value | array | list | group
##
## value-list = value | value-list "," value
##
## scalar-value = boolean | integer | integer64 | hex | hex64 | float
##                | string
##
## scalar-value-list = scalar-value | scalar-value-list "," scalar-value
##
## array = "[" (scalar-value-list | empty) "]"
##
## list = "(" (value-list | empty) ")"
##
## group = "{" (setting-list | empty) "}"
##
## empty =
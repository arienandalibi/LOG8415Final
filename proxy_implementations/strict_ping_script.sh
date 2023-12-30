#!/bin/bash

##
#list of servers
servers=($manager_private_dns ${worker1privateDNS} ${worker2privateDNS} ${worker3privateDNS})

# Ping and see which one responds fastest
minPing=21474836
maxPing=0
fastest=" "
pings=()
for server in "$${servers[@]}"; do
    result=$(ping -c 1 "$server" | grep "time=" | awk -F'=' '{print $4}' | cut -d' ' -f1)
    ping=$((10#$${result//"."}))
    pings+=($(($ping * 100)))
    if [ "$ping" -lt "$minPing" ]; then
      minPing=$ping
      fastest=$server
    fi
    if [ "$ping" -gt "$maxPing" ]; then
      maxPing=$ping
    fi
done

command="UPDATE mysql_servers SET status = CASE "
i=0
port=3306
for server in "$${servers[@]}"; do
    if [ "$${pings[i]}" -eq "$minPing" ]; then
      command+="WHEN port = $port THEN 'ONLINE' "
    else
      command+="WHEN port = $port THEN 'OFFLINE_SOFT' "
    fi
    ((i++))
    ((port++))
done
command+="END;"
mysql -u admin -padmin -h 127.0.0.1 -P 6032 <<LOL
$command
LOL
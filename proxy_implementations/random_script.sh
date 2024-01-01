#!/bin/bash
# If we want to use the random pattern, we can simply not do anything, since ProxySQL will automatically assign
# Weights of 1 to each server, meaning each server will be used the same amount, and requests will be essentially random.
# Otherwise, we can use the following script:
servers=($manager_private_dns ${worker1privateDNS} ${worker2privateDNS} ${worker3privateDNS})
command="UPDATE mysql_servers SET status = CASE "
i=0
# use random number to select server
random=$((RANDOM % 4))
for server in "$${servers[@]}"; do
    if [ $i -eq $random ]; then
      command+="WHEN hostname = '$server' THEN 'ONLINE' "
    else
      command+="WHEN hostname = '$server' THEN 'OFFLINE_SOFT' "
    fi
    ((i++))
done
command+="END;"
mysql -u admin -padmin -h 127.0.0.1 -P 6032 <<LOL
\$command
LOL
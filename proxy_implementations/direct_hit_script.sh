# If we want to use the direct hit pattern, instead of running the script, we change the rule to send all traffic to the master node
mysql -u admin -padmin -h 127.0.0.1 -P 6032 <<EOF
DELETE FROM mysql_query_rules;
INSERT INTO mysql_query_rules (rule_id, active, match_digest, destination_hostgroup, log, apply) VALUES (1, 1, '^.*$', 0, 1, 1);
LOAD MYSQL QUERY RULES TO RUNTIME;
SAVE MYSQL QUERY RULES TO DISK;
EOF
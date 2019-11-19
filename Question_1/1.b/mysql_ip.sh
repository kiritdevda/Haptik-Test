#!/bin/bash
mysql_username=root
mysql_password=rootpass
mysql_host=localhost

echo
read -p "mysql host (default : localhost)" mysql_host
mysql_host=${mysql_host:=mysql_host}
echo 

echo
read -p "mysql username (default : root)" mysql_username
mysql_username=${mysql_username:=mysql_username}
echo

echo
read -p "mysql password (default : root)" mysql_password
mysql_password=${mysql_password:=mysql_password}
echo

mysql -h${mysql_host}  -u${mysql_username} -p${mysql_password} << EOF
select distinct host from information_schema.processlist WHERE ID=connection_id();
exit;
EOF

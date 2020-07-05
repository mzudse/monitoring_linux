#!/bin/bash
source /home/shelly/monitoring/usm.config

# !status numbers explanation!
# 0 = not running
# 1 = running
# 2 = scan disabled

if [ $cfg_redis_check == "on" ]
then
	redis_status=$(redis-cli ping) #PONG
	echo "redis check enabled"
	if [ $redis_status == "PONG" ]
	then
		redis_status_value=1
	else
		redis_status_value=0
	fi
else
	redis_status_value=2
fi

#services
if [ $cfg_apache_check == "on" ]
then
	apache2_status=$(systemctl status apache2 | grep -i active | tr -s ' ' | cut -d ' ' -f 4) # (running)
	apache2_version=$(/usr/sbin/apache2 -v | grep 'Server version' | tr -s ' ' | cut -d ' ' -f 3 | grep 'Apache' | cut -d '/' -f 2)

	if [ $apache2_status == "(running)" ]
	then
		apache2_status_value=1
		apache2_version_value=$apache2_version
	else
		apache2_status_value=0
		apache2_version_value=0
	fi

else
	apache2_status_value=2
	apache2_version_value=2
fi

if [ $cfg_mysql_check == "on" ]
then
	mysql_status=$(service mysql status | grep -i active | tr -s ' ' | cut -d ' ' -f 4) # (running)
	mysql_version=$(mysql -V | grep 'Ver' | tr -s ' ' | cut -d ' ' -f 5 | sed 's/,$//') # cut , at the end

	if [ $mysql_status == "(running)" ]
	then
		mysql_status_value=1
		mysql_version_value=$mysql_version
	else
		mysql_status_value=0
		mysql_version_value=0
	fi
else

	mysql_status_value=2
	mysql_version_value=2
fi


#resources
ram_free=$(free -m  | grep ^Mem | tr -s ' ' | cut -d ' ' -f 6)
ram_used=$(free -m  | grep ^Mem | tr -s ' ' | cut -d ' ' -f 3)
ram_total=$(free -m  | grep ^Mem | tr -s ' ' | cut -d ' ' -f 2)

swap_used=$(free -m  | grep ^Swap | tr -s ' ' | cut -d ' ' -f 3)
swap_total=$(free -m  | grep ^Swap | tr -s ' ' | cut -d ' ' -f 2)

partition_1_total=$(df -h  | grep ^/dev/root | tr -s ' ' | cut -d ' ' -f 2)
partition_1_used=$(df -h  | grep ^/dev/root | tr -s ' ' | cut -d ' ' -f 3)
partition_2_total=$(df -h  | grep ^/dev/md3 | tr -s ' ' | cut -d ' ' -f 2)
partition_2_used=$(df -h  | grep ^/dev/md3 | tr -s ' ' | cut -d ' ' -f 3)

cpu_name=$(lscpu | grep 'Model name:' | sed -r 's/Model name:\s{1,}//g')
cpu_cores=$(nproc)
cpu_usage_total=$(awk -v a="$(awk '/cpu /{print $2+$4,$2+$4+$5}' /proc/stat; sleep 1)" '/cpu /{split(a,b," "); print 100*($2+$4-b[1])/($2+$4+$5-b[2])}' /proc/stat)

#system
os_name="ubuntu" #ofc ;)
os_version=$(lsb_release -r -s)
uptime=$(uptime | sed -E 's/^[^,]*up *//; s/, *[[:digit:]]* users.*//; s/min/minutes/; s/([[:digit:]]+):0?([[:digit:]]+)/\1 hours, \2 minutes/')

load_avg1=$(uptime | tr -s ' ' | cut -d ' ' -f 11 | sed 's/,$//')
load_avg2=$(uptime | tr -s ' ' | cut -d ' ' -f 12 | sed 's/,$//')
load_avg3=$(uptime | tr -s ' ' | cut -d ' ' -f 13 | sed 's/,$//')



curl -v -d "redis_status=$redis_status_value&apache_status=$apache2_status_value&apache_version=$apache2_version_value&mysql_status=$mysql_status_value&mysql_version=$mysql_version_value&ram_free=$ram_free&ram_used=$ram_used&ram_total=$ram_total&swap_used=$swap_used&swap_total=$swap_total&partition_1_total=$partition_1_total&partition_1_used=$partition_1_used&partition_2_total=$partition_2_total&partition_2_used=$partition_2_used&cpu_name=$cpu_name&cpu_cores=$cpu_cores&cpu_usage_total=$cpu_usage_total&os_name=$os_name&os_version=$os_version&uptime=$uptime&load_avg1=$load_avg1&load_avg2=$load_avg2&load_avg3=$load_avg3" -X POST $cfg_master_server

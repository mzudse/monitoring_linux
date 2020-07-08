#!/bin/bash
#set -xv
#while true; do
SCRIPT_VERSION="1.0.0"

URL_ENDPOINT="example.com"

textreset='\033[0m'
red='\033[0;31m'
yellow='\033[1;33m'
green='\033[0;32m'
white='\033[1;37m'

# Status codes
# 0 = offline/not running
# 1 = online/running
# 2 = not installed
# 3 = check disabled

if [ $(id -u) -ne 0 ]; then
	echo -e "${red} ERROR: you have to run this as root ${textreset}"
	exit 1;
fi

# Check if curl is installed
command -v curl >/dev/null 2>&1 || { echo -e >&2 "${red} ERROR: curl is not installed. Please install it. ${textreset}"; exit 1; }

# Check if jq is installed
command -v jq >/dev/null 2>&1 || { echo -e >&2 "${red} ERROR: jq is not installed. Please install it. ${textreset}"; exit 1; }

# Check if screen is installed
command -v screen >/dev/null 2>&1 || { echo -e >&2 "${red} ERROR: screen is not installed. Please install it. ${textreset}"; exit 1; }

# Check if iostat is installed
command -v iostat >/dev/null 2>&1 || { echo -e >&2 "${red} ERROR: iostat/sysstat is not installed. Please install it. ${textreset}"; exit 1; }

OS_NAME="unknown"

# Get OS name
OS_NAME=$(hostnamectl | grep "Operating System" | tr -s ' ' | cut -d ' ' -f 4)

# Check if OS is supported
if [ "$OS_NAME" != "Ubuntu" ] && [ "$OS_NAME" != "Debian" ]; then
	echo -e "${red} ERROR: Your OS is not supported ${textreset}";
	exit 1;
fi

# endpoint
CURL_SETTINGS=$(curl -s http://"$URL_ENDPOINT"/monitoring/heartbeat/getsettings)
echo "$CURL_SETTINGS" > tempsettings.json
# enable/disable checks
APACHE2_CHECK=$(jq '.apache2' tempsettings.json)
NGINX_CHECK=$(jq '.nginx' tempsettings.json)
MYSQL_CHECK=$(jq '.mysql' tempsettings.json)
REDIS_CHECK=$(jq '.redis' tempsettings.json)
MONGODB_CHECK=$(jq '.mongodb' tempsettings.json)
DOCKER_CHECK=$(jq '.docker' tempsettings.json)
SCREEN_CHECK_LIST=$(jq '.screenlist' tempsettings.json)
DOCKER_CONTAINER_CHECK_LIST=$(jq '.dclist' tempsettings.json)
#SOFTRAID_CHECK="true"

# *** set default values - start ***
OS_VERSION="0"

APACHE2_STATUS="unknown"
NGINX_STATUS="unknown"
MYSQL_STATUS="unknown"
REDIS_STATUS="unknown"
MONGODB_STATUS="unknown"
DOCKER_STATUS="unknown"

CPU_MODEL="unknown"
CPU_CORES="0"
CPU_THREADS="0"
CPU_USAGE="0"
CPU_TEMPS="0"
RAM_TOTAL="0"
RAM_USED="0"
RAM_FREE="0"

SWAP_TOTAL="0"
SWAP_USED="0"
SWAP_FREE="0"

HDD_TEMP="0"
# *** set default values - end ***

RX1=$(cat /sys/class/net/eth0/statistics/rx_bytes)
TX1=$(cat /sys/class/net/eth0/statistics/tx_bytes)
RX1_P=$(cat /sys/class/net/eth0/statistics/rx_packets)
TX1_P=$(cat /sys/class/net/eth0/statistics/tx_packets)

RX1_E=$(cat /sys/class/net/eth0/statistics/rx_errors)
TX1_E=$(cat /sys/class/net/eth0/statistics/tx_errors)

RX1_D=$(cat /sys/class/net/eth0/statistics/rx_dropped)
TX1_D=$(cat /sys/class/net/eth0/statistics/tx_dropped)

# Get uptime
UPTIME=$(uptime | tr -s ',' | cut -d ',' -f 1)

# Get loadavg
LOADAVG=$(cat /proc/loadavg | awk '{print $1, $2, $3}')

# Get OS version
OS_VERSION=$(hostnamectl | grep "Operating System" | tr -s ' ' | cut -d ' ' -f 5)

# Get nginx status
if [ "$NGINX_CHECK" = "true" ]; then
	if [ "$(service nginx status | grep 'Loaded' | tr -s ' ' | cut -d ' ' -f 3)" = "loaded" ]; then
		#installed
                if [ "$(service nginx status | grep 'Active' | tr -s ' ' | cut -d ' ' -f 3)" = "active" ]; then
                        #running
                        echo -e "${yellow}INFO:${textreset} nginx running"
                        NGINX_STATUS="1"
                else
                        #not running
                        echo -e "${yellow}INFO:${textreset} nginx not running${textreset}"
                        NGINX_STATUS="0"
                fi
	else
		#not installed
		echo -e "${yellow}INFO:${textreset} nginx is not installed"
		NGINX_STATUS="2"
	fi
else
	NGINX_STATUS="3"
fi

# Get apache2 status
if [ "$APACHE2_CHECK" = "true" ]; then
        if [ "$(service apache2 status | grep 'Loaded' | tr -s ' ' | cut -d ' ' -f 3)" = "loaded" ]; then
                #installed
		if [ "$(service apache2 status | grep 'Active' | tr -s ' ' | cut -d ' ' -f 3)" = "active" ]; then
			#running
			echo -e "${yellow}INFO:${textreset} apache2 running"
			APACHE2_STATUS="1"
		else
			#not running
			echo -e "${yellow}INFO:${textreset} apache2 not running"
			APACHE2_STATUS="0"
		fi
        else
		#not installed
		echo -e "${yellow}INFO:${textreset} apache2 is not installed"
                APACHE2_STATUS="2"
        fi
else
	APACHE2_STATUS="3"
fi

# Get mysql status
if [ "$MYSQL_CHECK" = "true" ]; then
        if [ "$(service mysql status | grep 'Loaded' | tr -s ' ' | cut -d ' ' -f 3)" = "loaded" ]; then
                #installed
                if [ "$(service mysql status | grep 'Active' | tr -s ' ' | cut -d ' ' -f 3)" = "active" ]; then
                        #running
                        echo -e "${yellow}INFO:${textreset} mysql running"
                        MYSQL_STATUS="1"
                else
                        #not running
                        echo -e "${yellow}INFO:${textreset} mysql not running"
                        MYSQL_STATUS="0"
                fi
        else
                #not installed
                echo -e "${yellow}INFO:${textreset} mysql is not installed"
                MYSQL_STATUS="2"
        fi
else
	MYSQL_STATUS="3"
fi

# Get redis status
if [ "$REDIS_CHECK" = "true" ]; then
        if [ "$(service redis status | grep 'Loaded' | tr -s ' ' | cut -d ' ' -f 3)" = "loaded" ]; then
                #installed
                if [ "$(service redis status | grep 'Active' | tr -s ' ' | cut -d ' ' -f 3)" = "active" ]; then
                        #running
                        echo -e "${yellow}INFO:${textreset} redis running"
                        REDIS_STATUS="1"
                else
                        #not running
                        echo -e "${yellow}INFO:${textreset} redis not running"
                        REDIS_STATUS="0"
                fi
        else
                #not installed
                echo -e "${yellow}INFO:${textreset} redis is not installed"
                REDIS_STATUS="2"
        fi
else
	REDIS_STATUS="3"
fi

# Get mongodb status
if [ "$MONGODB_CHECK" = "true" ]; then
        if [ "$(service mongod status | grep 'Loaded' | tr -s ' ' | cut -d ' ' -f 3)" = "loaded" ]; then
                #installed
                if [ "$(service mongod status | grep 'Active' | tr -s ' ' | cut -d ' ' -f 3)" = "active" ]; then
                        #running
                        echo -e "${yellow}INFO:${textreset} mongod running"
                        MONGODB_STATUS="1"
                else
                        #not running
                        echo -e "${yellow}INFO:${textreset} mongod not running"
                        MONGODB_STATUS="0"
                fi
        else
                #not installed
                echo -e "${yellow}INFO:${textreset} mongod is not installed"
                MONGODB_STATUS="2"
        fi
else
	MONGODB_STATUS="3"
fi

# Get docker status
if [ "$DOCKER_CHECK" = "true" ]; then
        if [ "$(service docker status | grep 'Loaded' | tr -s ' ' | cut -d ' ' -f 3)" = "loaded" ]; then
                #installed
                if [ "$(service docker status | grep 'Active' | tr -s ' ' | cut -d ' ' -f 3)" = "active" ]; then
                        #running
                        echo -e "${yellow}INFO:${textreset} docker running"
                        DOCKER_STATUS="1"
                else
                        #not running
                        echo -e "${yellow}INFO:${textreset} docker not running"
                        DOCKER_STATUS="0"
                fi
        else
                #not installed
                echo -e "${yellow}INFO:${textreset} docker is not installed"
                DOCKER_STATUS="2"
        fi
else
	DOCKER_STATUS="3"
fi

# Get cpu usage
CPU_MODEL=$(lscpu | grep 'Model name:' | sed -r 's/Model name:\s{1,}//g')
CPU_CORES=$(grep ^cpu\\scores /proc/cpuinfo | uniq |  awk '{print $4}')
CPU_THREADS=$(nproc)
#CPU_USAGE=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print usage}')
CPU_USAGE=$[100-$(vmstat 1 2|tail -1|awk '{print $15}')]

# Get ram usage
RAM_TOTAL=$(free -m | grep 'Mem' | tr -s ' ' | cut -d ' ' -f 2)
RAM_USED=$(free -m | grep 'Mem' | tr -s ' ' | cut -d ' ' -f 3)
RAM_FREE=$(free -m | grep 'Mem' | tr -s ' ' | cut -d ' ' -f 6)
SWAP_TOTAL=$(free -m | grep 'Swap' | tr -s ' ' | cut -d ' ' -f 2)
SWAP_USED=$(free -m | grep 'Swap' | tr -s ' ' | cut -d ' ' -f 3)
SWAP_FREE=$(free -m | grep 'Swap' | tr -s ' ' | cut -d ' ' -f 4)

PARTITION_RETURN_STRING=""
PARTITION_TEMP_STRING=""

# answer on my question: https://stackoverflow.com/questions/55007300/bash-script-expression-syntax-crash-in-loop?noredirect=1#comment96769891_55007300
# replaces my old code (below)
PARTITION_RETURN_STRING=$(df -m | sed -e 1d | tr -s ' ' | tr ' \n' '#|')

# Code crashs the script after the first run in a while loop
#for i in $(df | awk '{ print $6 }')
#do
#        if [ "$i" != "Mounted" ]; then
#		for abc in $(seq 1 6)
#                do
#                	PARTITION_TEMP_STRING=$(df -m | awk -v bla="$i" '$6 == bla' | tr -s ' ' | cut -d ' ' -f $abc)
#                	PARTITION_RETURN_STRING="$PARTITION_RETURN_STRING$PARTITION_TEMP_STRING"
#                	if [ "$(($abc%6))" = "0" ]; then
#	        		PARTITION_RETURN_STRING+="|"
#                	else
#                		PARTITION_RETURN_STRING+="#"
#                	fi
#                done
#        fi
#done

echo "#####################################"
echo -e "${yellow}HARDWARE INFO${textreset}"
echo "#####################################"

DISC_STATUS_STRING=""
DISCSTATUS=""
bubcounter="0"
for i in $(lsblk -io KNAME,TYPE | grep 'disk' | tr -s ' ' | cut -d ' ' -f 1)
do
	bubcounter=$((bubcounter+1))
	i=${i//$'\n'/}
        if [ -z "$(smartctl -H /dev/$i | grep 'PASSED')" ]; then
                echo "INFO: disc $i error/warning"
		DISCSTATUS="error"
        else
		echo "INFO: disc $i OK"
                DISCSTATUS="ok"
        fi
	TMP_IO_1=$(iostat | grep "$i" | tr -s ' ' | cut -d ' ' -f 2)
	TMP_IO_2=$(iostat | grep "$i" | tr -s ' ' | cut -d ' ' -f 3)
	TMP_IO_3=$(iostat | grep "$i" | tr -s ' ' | cut -d ' ' -f 4)
	DISC_IO+="$bubcounter#$i#$TMP_IO_1#$TMP_IO_2#$TMP_IO_3|"
	DISC_STATUS_STRING+="$i#"
	DISC_STATUS_STRING+="$DISCSTATUS|"
	DISCSTATUS=""
done

SCREEN_CHECK_STATUS=""
SCREEN_SINGLE_STATUS="0"
SCREEN_CHECK_LIST=$(echo "$SCREEN_CHECK_LIST" | sed 's/\"//g')
IFS="," # internal field separator
for screenname in $SCREEN_CHECK_LIST
do
	SCREEN_USERNAME=${screenname%#*}
	SCREEN_NAME_A=${screenname##$SCREEN_USERNAME}
	SCREEN_NAME_A=${SCREEN_NAME_A:1}
	echo $SCREEN_USERNAME
	if [ -z "$(getent passwd $SCREEN_USERNAME)" ]; then
		SCREEN_SINGLE_STATUS="2" # user does not exist
	else
		if [ "$(sudo -u $SCREEN_USERNAME screen -ls | grep $SCREEN_NAME_A)" ]; then
			SCREEN_SINGLE_STATUS="1"
		else
			SCREEN_SINGLE_STATUS="0"
		fi
	fi
	SCREEN_CHECK_STATUS="$SCREEN_CHECK_STATUS$SCREEN_NAME_A#$SCREEN_SINGLE_STATUS|"
done
SCREEN_CHECK_STATUS=$(echo "$SCREEN_CHECK_STATUS" | sed 's/\"//g')

#
# TODO? ÜBERRPÜFEN OB DOCKER ÜBERHAUPT LÄUFT! BZW angeschaltet ist
#
DOCKER_CONTAINER_CHECK_STATUS=""
CINTAINER_STATUS="0"
DOCKER_CONTAINER_CHECK_LIST=$(echo "$DOCKER_CONTAINER_CHECK_LIST" | sed 's/\"//g')
IFS="," # internal field separator
for containerid in $DOCKER_CONTAINER_CHECK_LIST
do
	if [ "$DOCKER_STATUS" = "1" ]; then
		if [ "$(docker inspect -f '{{.State.Running}}' $containerid)" = "true" ]; then
        		CONTAINER_STATUS="1"
		else
        		CONTAINER_STATUS="0"
        	fi
	else
		CONTAINER_STATUS="0" # offline, because DOCKER is not running
	fi
        DOCKER_CONTAINER_CHECK_STATUS="$DOCKER_CONTAINER_CHECK_STATUS$containerid#$CONTAINER_STATUS|"
done
DOCKER_CONTAINER_CHECK_STATUS=$(echo "$DOCKER_CONTAINER_CHECK_STATUS" | sed 's/\"//g')
sleep 0.1
RX2=$(cat /sys/class/net/eth0/statistics/rx_bytes)
TX2=$(cat /sys/class/net/eth0/statistics/tx_bytes)

RX2_P=$(cat /sys/class/net/eth0/statistics/rx_packets)
TX2_P=$(cat /sys/class/net/eth0/statistics/tx_packets)

RX2_E=$(cat /sys/class/net/eth0/statistics/rx_errors)
TX2_E=$(cat /sys/class/net/eth0/statistics/tx_errors)

RX2_D=$(cat /sys/class/net/eth0/statistics/rx_dropped)
TX2_D=$(cat /sys/class/net/eth0/statistics/tx_dropped)

RX_DONE=$(( (RX2-RX1) / 1024 )) #kb
TX_DONE=$(( (TX2-TX1) / 1024 )) #kb

RX_P_DONE=$(( RX2_P-RX1_P ))
TX_P_DONE=$(( TX2_P-TX1_P ))

RX_E_DONE=$(( RX2_E-RX1_E ))
TX_E_DONE=$(( TX2_E-TX1_E ))

RX_D_DONE=$(( RX2_D-RX1_D ))
TX_D_DONE=$(( TX2_D-TX1_D ))
RXTX="$RX_P_DONE,$TX_P_DONE,$RX_E_DONE,$TX_E_DONE,$RX_D_DONE,$TX_D_DONE"


echo "OS NAME: $OS_NAME"
echo "OS VERSION $OS_VERSION"

echo "CPU MODEL: $CPU_MODEL"
echo "CPU CORES: $CPU_CORES"
echo "CPU THREADS: $CPU_THREADS"
echo "CPU USAGE: $CPU_USAGE"

echo "RAM TOTAL: $RAM_TOTAL"
echo "RAM USED: $RAM_USED"
echo "RAM FREE: $RAM_FREE"
echo "SWAP TOTAL: $SWAP_TOTAL"
echo "SWAP USED: $SWAP_USED"
echo "SWAP FREE: $SWAP_FREE"
echo -e "${yellow} PARTITION DATA STRING BELOW ${textreset}"
echo "$PARTITION_RETURN_STRING"
echo -e "${yellow} DISC DATA STRING BELOW ${textreset}"
echo "$DISC_STATUS_STRING"
echo -e "${yellow} SCREEN DATA BELOW ${textreset}"
echo "SCREENS: $SCREEN_CHECK_STATUS"
echo -e "${yellow} DOCKER CONTAINER DATA BELOW ${textreset}"
echo "$DOCKER_CONTAINER_CHECK_STATUS"

CURL_POST_DATA="uptime=$UPTIME&loadavg=$LOADAVG&screen=$SCREEN_CHECK_STATUS&rxtx=$RXTX&io=$DISC_IO&rx_done=$RX_DONE&tx_done=$TX_DONE&apache2_status=$APACHE2_STATUS&nginx_status=$NGINX_STATUS&mysql_status=$MYSQL_STATUS&redis_status=$REDIS_STATUS&mongodb_status=$MONGODB_STATUS&docker_status=$DOCKER_STATUS&os_name=$OS_NAME&os_ver=$OS_VERSION&cpu_model=$CPU_MODEL&cpu_cores=$CPU_CORES&cpu_threads=$CPU_THREADS&cpu_usage=$CPU_USAGE&ram_total=$RAM_TOTAL&ram_used=$RAM_USED&ram_free=$RAM_FREE&swap_total=$SWAP_TOTAL&swap_used=$SWAP_USED&swap_free=$SWAP_FREE&partition_data=$PARTITION_RETURN_STRING&disc_data=$DISC_STATUS_STRING&screen_data=$SCREEN_CHECK_STATUS&docker_container_data=$DOCKER_CONTAINER_CHECK_STATUS"

curl=$(curl  -d "$CURL_POST_DATA" -X POST http://example.com/monitoring/heartbeat/hb)
echo "$curl"
#sleep 30
#done

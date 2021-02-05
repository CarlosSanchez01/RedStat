#!/bin/bash

printf "######################### Configuration #####################\n\n"

printf "the present script sets a hostname of preference and activate ssh for future connections with your Raspberry pi\n"
printf "[ctrl + c] if you wanna exit\n\n"

printf "##############################################\n\n"

if test "`id -u`" -ne 0
	then 
	printf "You need to run this script as root!\n" 
	exit 
fi

printf 'Do you want to set your hostname and activate ssh?[y/n]\n'
read -r
response=$REPLY
printf "Your answer is: "
printf $response
printf "\n"
# routine to set hostname, password and enable ssh
if [ $response == "y" ]
    then
    printf "How do you want to name your Raspberry pi?\n"
    read hostname
    # stablish hostname
    file_hosts="/etc/hosts"
    printf "########################## /etc/hosts begin #####################\n"
    cat $file_hosts
    printf "\n\n########################## /etc/hosts end #####################\n\n\n"
    sudo sed -i '$d' $file_hosts
    sudo printf "127.0.1.1	$hostname" >> $file_hosts
    printf "########################## UPDATED /etc/hosts begin #####################\n"
    cat $file_hosts
    printf "\n\n########################## UPDATED /etc/hosts end #####################\n\n\n"

    file_hostname="/etc/hostname"
    printf "########################## /etc/hostname begin #####################\n"
    cat $file_hostname
    printf "\n\n########################## /etc/hostname end #####################n\n\n"
    sudo printf "$hostname" > $file_hostname
    printf "########################## UPDATED /etc/hostname begin #####################\n"
    cat $file_hostname
    printf "\n\n########################## UPDATED /etc/hostname end #####################\n \n\n"
    
    # change password default
    printf "##############################################\n"
    printf "##############################################\n\n"

    printf "It is advised to change the default password\n"
    printf "Default password on your pi is 'raspberry'\n"
    printf "Should we change your password? [y/n]\n"
    read -r
    printf "Your answer is: "
    response=$REPLY
    printf $response
    printf "\n"

    if [ $response == "y" ]
        then
            sudo -u passwd
            printf "You just changed your password\n"
    else 
        printf "You did not change your password\n"
    fi

    # enable ssh
    printf "Should we enable ssh? [y/n]\n"
    read -r
    response=$REPLY
    printf "Your answer is: "
    printf $response
    printf "\n"
    if [ $response == "y" ]
    then
        printf "enabling ssh...\n"
        sudo systemctl enable ssh
        sudo systemctl start ssh
        printf "You just enabled ssh\n"
    else 
        printf "You did not enable ssh\n"
    fi

else
    printf "You did not change hostname or password\n"
fi
###############################################################################
###############################################################################
###############################################################################
###############################################################################
printf "\n\n######################### Installation #####################\n\n"
printf "This script also update your Rpi and installs influxdb, grafana and nodered \n"
echo "[ctrl + c] if you wanna exit"

printf "##############################################\n\n"

printf "Do you want to install [all/update/influxdb/grafana/nodered]?\n"

read -r
input=$REPLY
printf "Your answer is: "
printf $input
printf "\n"

if [ $input == "update" ]
    then
	printf "Updating Rpi installation...\n\n"
	apt-get update  # To get the latest package lists
	apt-get upgrade  # To get the latest package lists

elif [ $input == "all" ]
    then
	printf "Updating Rpi installation...\n\n"
	apt-get update  # To get the latest package lists
	apt-get upgrade  # To get the latest package lists

	printf "Installing all...\n"
	printf "installing pre-requirements...\n"
	sudo apt install build-essential git

	printf "Installing influxdb...\n"
	wget -qO- https://repos.influxdata.com/influxdb.key | sudo apt-key add -
	sudo systemctl unmask influxdb.service
    sudo systemctl start influxdb
    sudo systemctl enable influxdb.service
	printf "##############################################\n\n"
    printf "Creating dstat database...\n"
    influx -execute 'CREATE dstat'
    printf "Now 'dstat' should be one database to use with INFLUX...\n"
    influx -execute 'SHOW DATABASES'
    printf "##############################################\n\n"

	printf "Installing grafana...\n"
	wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
	printf "deb https://packages.grafana.com/oss/deb stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list
	sudo apt update
	sudo apt install grafana
	sudo systemctl enable grafana-server
	sudo systemctl start grafana-server

	printf "installing nodered...\n"
	web=https://raw.githubusercontent.com/CarlosSanchez01/RedStat/script-for-nodered-changed-with-sed/.nodered.sh
    wget $web -O .nodered.sh
    printf "I substitute the extranodes in the installation script to match the requirements of our dstat flow...\n"
    sed -i 's/EXTRANODES="node-red-node-pi-gpio@latest node-red-node-random@latest node-red-node-ping@latest node-red-contrib-play-audio@latest node-red-node-smooth@latest node-red-node-serialport@latest"/EXTRANODES="node-red-node-pi-gpio@latest node-red-node-serialport@latest node-red-node-ui-table node-red-dashboard node-red-contrib-influxdb"/' .nodered.sh
    sudo  bash .nodered.sh --confirm-root --confirm-install --confirm-pi
	# node-red-pi --max-old-space-size=256
	# printf "Installing missing modules...\n"
    # sudo npm init
    printf "setting nodered as a service...\n"
	sudo systemctl enable nodered.service

elif [ $input == "influxdb" ]
    then
	printf "Installing influxdb...\n"
	wget -qO- https://repos.influxdata.com/influxdb.key | sudo apt-key add -
	sudo apt update
    sudo systemctl unmask influxdb.service
    sudo systemctl start influxdb
    sudo systemctl enable influxdb.service
    printf "Creating dstat database...\n"
    influx -execute 'CREATE dstat'
    printf "Now 'dstat' should be one database to use with INFLUX...\n"
    influx -execute 'SHOW DATABASES'
    printf "\n\n"

elif [ $input == "grafana" ]
    then
  	printf "Installing grafana...\n"
	wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
	printf "deb https://packages.grafana.com/oss/deb stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list
	sudo apt update
	sudo apt install grafana
	sudo systemctl enable grafana-server
	sudo systemctl start grafana-server

elif [ $input == "nodered" ]
    then
	printf "installing nodered...\n"
	web=https://raw.githubusercontent.com/CarlosSanchez01/RedStat/script-for-nodered-changed-with-sed/.nodered.sh
    wget $web -O .nodered.sh
    printf "I substitute the extranodes in the installation script to match the requirements of our dstat flow...\n"
    sed -i 's/EXTRANODES="node-red-node-pi-gpio@latest node-red-node-random@latest node-red-node-ping@latest node-red-contrib-play-audio@latest node-red-node-smooth@latest node-red-node-serialport@latest"/EXTRANODES="node-red-node-pi-gpio@latest node-red-node-serialport@latest node-red-node-ui-table node-red-dashboard node-red-contrib-influxdb"/' .nodered.sh
    sudo  bash .nodered.sh --confirm-root --confirm-install --confirm-pi
	# node-red-pi --max-old-space-size=256
	# printf "Installing missing modules...\n"
    # sudo npm init
    printf "\n"
	printf "setting nodered as a service...\n"
	# node-red-pi --max-old-space-size=256
	sudo systemctl enable nodered.service

else 
    printf "We did not update or install anything...\n\n"
fi 

###############################################################################
###############################################################################
###############################################################################
###############################################################################
printf "\n"
printf "We are gonna reboot now!"
printf "After reboot open a web browser in your network \n"
printf "at <'raspberryPi_hostname':1880> to see your node-red instance \n"
printf "check for grafana in <'raspberryPi_hostname':3000> \n\n"
printf "Happy work\n\n"

for i in {5..1}
do 
    printf "$i\n"
    sleep 1
done
sudo reboot
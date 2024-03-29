#!/bin/bash
# run as root 
if [[ $UID != 0 ]]; then
    echo "Please run this script with sudo:"
    echo "sudo $0 $*"
    exit 1
fi

# set colors
green=`tput setaf 2`
red=`tput setaf 1`
normal=`tput sgr0`
bold=`tput bold`

# start
clear
echo -e "\e[1;31m--------------------------------------------------\e[00m"
echo -e "\e[01;31m[-.-]\e[00m Muddydev Ubuntu wordpress installer v1.2"
echo -e "\e[1;31m--------------------------------------------------\e[00m"
echo ""
echo -e "\e[01;31m[x]\e[00m Dont forget to configure your DNS FIRST!!"
echo ""
echo -e "\e[1;31m--------------------------------------------------\e[00m"
read -e -p "Installer adds site files to /var/www, Is that ok (y/n)? "
[ "$(echo $REPLY | tr [:upper:] [:lower:])" == "y" ] || exit

# Install WP
#read -e -p "Would you like to download the newest version of WordPress (y/n)? " wpFiles
wpFiles=y
if [ $wpFiles == "y" ]; then
	read -e -p "What would you like the database to be called: " dbname
	read -e -p "Who will be the database user account (usually wordpress): " dbuser

	# If you are going to use root ask about it	
	if [ $dbuser == 'root' ]; then
		read -e -p "${red}root is not recommended. Use it (y/n)?${normal} " useroot

		if [ $useroot == 'n' ]; then
			read -e -p "Database username: " dbuser
		fi
	else
		useroot='n'
	fi

	read -e -s -p "Enter a password for user $dbuser: " userpass
	echo " "

	# Create MySQL database
	#read -e -p "Auto Create database and user if not found? (y/n) " dbadd
	dbadd=y
	if [ $dbadd == "y" ]; then
		read -e -s -p "Enter your MySQL root password: " rootpass
		echo " "

		if [ ! -d /var/lib/mysql/$dbname ]; then
			echo "CREATE DATABASE $dbname;" | mysql -u root -p$rootpass

			if [ -d /var/lib/mysql/$dbname ]; then
				echo " "
				#echo "${green}New MySQL database ($dbname) was successfully created${normal}"
				echo -e "\e[01;31m[✓]\e[00m New MySQL database ($dbname) was successfully created"
				echo " "
			else
				echo "${red}New MySQL database ($dbname) faild to be created${normal}"
			fi

		else
			echo "${red}Your MySQL database ($dbname) already exists${normal}"
		fi
		echo "Checking whether the $dbuser exists and has privileges"

		user_exists=`mysql -u root -p$rootpass -e "SELECT user FROM mysql.user WHERE user = '$dbuser'" | wc -c`
		if [ $user_exists = 0 ]; then
			echo "CREATE USER '$dbuser'@'localhost' IDENTIFIED BY '$userpass';" | mysql -u root -p$rootpass
			echo "${green}New MySQL user ($dbuser) was successfully created${normal}"
		else
			echo "${red}This MySQL user ($dbuser) already exists${normal}"
		fi

		user_has_privilage=`mysql -u root -p$rootpass -e "SELECT User FROM mysql.db WHERE db = '$dbname' AND user = '$dbuser'" | wc -c`
		if [ $user_has_privilage = 0 ]; then
			echo "GRANT ALL PRIVILEGES ON $dbname.* TO '$dbuser'@'localhost';" | mysql -u root -p$rootpass
			echo "FLUSH PRIVILEGES;" | mysql -u root -p$rootpass
			echo "${green}Add privilages for user ($dbuser) to DB $dbname${normal}"
		else 
			echo "${red}User ($dbuser) already has privilages to DB $dbname${normal}"
		fi

	fi

	# Download, unpack and configure WordPress
	read -e -r -p "Enter your URL without www [e.g. example.com]: " wpURL
	if [ ! -d /var/www/$wpURL ]; then
		cd /var/www
		wget -q http://wordpress.org/latest.tar.gz
		tar -xzf latest.tar.gz --transform s/wordpress/$wpURL/
		rm latest.tar.gz
		if [ -d /var/www/$wpURL ]; then
			echo "${green}WordPress downloaded.${normal}"
			cd /var/www/$wpURL
			cp wp-config-sample.php wp-config.php
			sed -i "s/database_name_here/$dbname/;s/username_here/$dbuser/;s/password_here/$userpass/" wp-config.php

			mkdir wp-content/uploads
			chmod 640 wp-config.php
			chmod 775 wp-content/uploads
			chown www-data: -R /var/www/$wpURL
			if [ -f /var/www/$wpURL/wp-config.php ]; then
				echo "${green}WordPress has been configured."
			else
				echo "${red}Created WP files. wp-config.php setup faild, do this manually.${normal}"
			fi
		else
			echo "${red}Failed to create WP files. Install them manually.${normal}"
		fi
	else
		echo "${red}Site folder already exists.${normal}"
	fi

else
	echo "Skipping WordPress install."
fi
# Create Apache virtual host
#read -p "Do you want to install Apache vhost (y/n)? " apacheFiles
apacheFiles=y
if [ $apacheFiles == "y" ]; then

	if [ -f /etc/apache2/sites-available/$wpURL ]; then
	    echo "${red}This site already has a vhost file.${normal}"
	else
	echo -e "\e[01;31m[✓]\e[00m Configuring the apache vhost"
	echo "
# Added to mitigate CVE-2017-8295 vulnerability
UseCanonicalName On

<VirtualHost *:80>
        ServerAdmin webmaster@localhost
        
        ServerName $wpURL
        ServerAlias www.$wpURL
        
        DocumentRoot /var/www/$wpURL

        <Directory /var/www/$wpURL/>
            Options FollowSymLinks
            AllowOverride All
            Require all granted
        </Directory>

        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>

" > /etc/apache2/sites-available/$wpURL.conf

	if [ -f /etc/apache2/sites-available/$wpURL.conf ]; then
		echo "${green}Apache vhost file created${normal}"
	else
		echo "${red}Apache vhost failed to install${normal}"
	fi

fi
# Enable the site
a2ensite $wpURL
echo ""
echo -e "\e[01;32m[~]\e[00m Apache needs Reloaded. Gonna do it now"
echo ""
service apache2 reload
sleep 3
echo ""
echo -e "\e[01;31m[✓]\e[00m Apache Reloaded"
echo ""
#curlText=`curl --user-agent "fogent" --silent "http://$wpURL/wp-admin/install.php" | grep -o -m 1 "Welcome to the famous five minute WordPress installation process" | wc -c`
curlText=`curl --silent https://lookingafterlupin.com/wp-admin/install.php | wc -c`
# http://www.cyberciti.biz/faq/how-to-find-out-the-ip-address-assigned-to-eth0-and-display-ip-only/
yourip=`curl --silent ifconfig.me`

if [ $curlText == '11946' ]; then
  echo "${green}Go to http://$wpURL and finish install.${normal}";
else
  echo ""
  echo ""
  echo "${green}Go to http://$wpURL and finish install.${normal}";
  echo ""
  echo ""
fi
else
	echo ""
	echo "Skipping Apache site install."
	echo ""
fi
#----------------------
#┌─┐┌─┐┬─┐┌┬┐┌┐ ┌─┐┌┬┐
#│  ├┤ ├┬┘ │ ├┴┐│ │ │ 
#└─┘└─┘┴└─ ┴ └─┘└─┘ ┴ 
#----------------------
#read -e -p "Install SSL wil Certbot (y/n)" sslinstall
sslinstall=y
if [ $sslinstall == "y" ]; then
	certbot
	echo "${green}Finished!${normal}"
else
	echo "${green}Finished with no SSL configured${normal}"
fi
echo -e "\e[1;31m--------------------------------------------------\e[00m"
echo -e "\e[01;31m[✓]\e[00m Currently active and enabled apache sites"
echo -e "\e[1;31m--------------------------------------------------\e[00m"
apache2ctl -S | grep www | grep alias | cut -d '.' -f2 | sort -u
echo -e "\e[1;31m--------------------------------------------------\e[00m"
echo ''
echo 'done!'

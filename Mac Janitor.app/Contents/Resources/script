#!/bin/bash

######################################################################################
# This script does some basic maintenance operations on Mac OS X (almost any version)#
#     v2.1 		     #
######################################################################################

# Defined colors
RED='\033[1;31m'
BLUE='\033[1;34m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
STOPCOLOR='\033[0m'

echo ${GREEN} MAC OS MAINTENANCE SCRIPT by Darien Entwistle  ${STOPCOLOR}
echo ${RED} Please close all applications before giving the administrator password! The script may ask for your password again during the maintenance process if one specific task takes more than 5 minutes to complete on your system. ${STOPCOLOR}

# Ask for super user passwd before printing the "Starting...". It just looks nicer.
sudo ls / > /dev/null

echo ${BLUE} Starting the maintenance process. ${STOPCOLOR}

# Syncs ntpd
echo ${YELLOW} Syncing Date and Time ${STOPCOLOR}
sudo ntpdate time.apple.com
echo ${GREEN} Done. ${STOPCOLOR}

# Clears font cache
echo ${YELLOW} Clearing font cache... ${STOPCOLOR}
sudo atsutil databases -remove
echo ${GREEN} Done. ${STOPCOLOR}

# Clean log files
echo ${YELLOW} Cleaning log files... ${STOPCOLOR}
sudo rm -rf /var/log/*
echo ${GREEN} Done. ${STOPCOLOR}

echo ${YELLOW} Emptying trash... ${STOPCOLOR}
# Force empty trash
sudo rm -rf ~/.Trash/*
echo ${GREEN} Done. ${STOPCOLOR}

echo ${YELLOW} Running built in maintenance scripts... ${STOPCOLOR}
# Run maintenance scripts
sudo periodic daily weekly monthly
echo ${GREEN} Done. ${STOPCOLOR}

echo ${YELLOW} Verifying HDD Volume ... ${STOPCOLOR}
#Verifies the whole Macintosh HDD volume
sudo diskutil verifyVolume /
echo ${GREEN} Done. ${STOPCOLOR}

echo ${YELLOW} Repairing startup volume... ${STOPCOLOR}
# Repairs startup volume
sudo fsck -fy
echo ${GREEN} Done. ${STOPCOLOR}

# Clears RAM for better memory mangement 
echo ${YELLOW} Clearing RAM Cache..... ${STOPCOLOR}
sudo purge
echo ${GREEN} Done. ${STOPCOLOR}
say "Mac Janitor has completed maintenance on your Mac, you can now quit the application"
echo ${BLUE} Finished the whole maintenance process. ${STOPCOLOR}



#!/bin/bash

######################################################################################
# This script does some  maintenance operations on Mac OS X (10.11 and greater)#
#     v2.9 		 Summer Build    #
######################################################################################


#lets check your Mac OS version
echo OS System Version Check
echo Version checking...............
sleep 1s
if [[ ${OSTYPE:6} -ge 15 ]]; then
    echo "Your Mac OS version is atleast 10.11, App will continue";
else
    echo "You have an INCOMPATIBLE Mac OS version! App will quit";
    sleep 3s
    exit
fi

## START

echo -n "Would you like to run Mac Janitor?? Otherwise 'N' for No to quit & cancel!! "
read answer
if echo "$answer" | grep -iq "^y" ;then
echo Continuing! ... Running Mac Janitor!
sleep 3s
else
echo Canceled! EXITING NOW!!!
sleep 3s
exit
fi


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

#Performs some OS optimization
echo ${YELLOW} OS Optimization ${STOPCOLOR}
sudo defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
sudo defaults write com.apple.Dock autohide-delay -float 0
sudo defaults write com.apple.finder DisableAllAnimations -bool true
#Make all animations faster that are used by Mission Control.
defaults write com.apple.dock expose-animation-duration -float 0.1
# Disable animations when you open an application from the Dock.
defaults write com.apple.dock launchanim -bool false
#reduce transparancy within menus and windows
######

#Disable Sudden Motion Sensor
echo -n "Is this Mac using an SSD? If yes lets optimize. Otherwise 'N' for No to continue!! "
read answer
if echo "$answer" | grep -iq "^y" ;then
echo  Disabling Sudden Motion Sensor.......
sleep 4s
sudo pmset -a sms 0
else
echo Continuing....
sleep 3s
echo ${GREEN} Continuing onto next part!!${STOPCOLOR}
fi

# Clears Quick look cache 
echo ${YELLOW} Clearing Quick Look cache... ${STOPCOLOR}
rm -rf $TMPDIR/../C/com.apple.QuickLook.thumbnailcache
echo ${GREEN} Quick Look Cache cleared!! ${STOPCOLOR}

#Clear DNS Cache
echo ${YELLOW} Clearing DNS cache... ${STOPCOLOR}
sudo dscacheutil -flushcache && \
sudo killall -HUP mDNSResponder
echo ${GREEN} DNS Cache cleared!! ${STOPCOLOR}

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

#SOFTWARE UPDATE CHECK
echo ${YELLOW} System Update Check! ${STOPCOLOR}
sudo softwareupdate -l
echo -n "Did you see updates? Need to Apply? Yes to Apply , No to Continue with NO Updating "
read answer
if echo "$answer" | grep -iq "^y" ;then
echo Updates will be applied!!!
sleep 4s
sudo softwareupdate -i -r
else
echo Continuing....
sleep 3s
say "Mac Janitor has completed maintenance on your Mac"
echo ${BLUE} Finished the whole maintenance process. ${STOPCOLOR}
say System Needs to restart!
echo Will will need to reboot. REBOOTING in 10 SECONDS!
echo .....
echo ..........
echo  ...............
sleep 10s
sudo reboot
fi


#! /bin/bash

# Testing if Git is installed, if not download and install it.

DIR=~/autoinstall
if [ ! -d "$DIR" ]; then
	echo
	echo "Downloading git script."
else 
	echo
	echo "Skript existing.. delete the loacal dir $DIR"
	exit
fi
echo
echo "Searching for git"
FILE=/usr/bin/git
REPO=https://github.com/Hvemmse/archinstalldanish
if [ -f "$FILE" ]; then
    echo
    echo "$FILE .. Found"
    git clone $REPO
   
else 
    echo
    echo "$FILE is not found, installing it now ...."

FILE=git
 echo
 echo $FILE
	pacman -Sy $FILE
	git clone $REPO
	
fi



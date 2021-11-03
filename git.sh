#! /bin/bash

# Test.sh for validering om et pkg er installeret, hvis ikke så installer den.

DIR=~/archinstalldanish
if [ ! -d "$DIR" ]; then
	echo
	echo "Henter github script."
else 
	echo
	echo "Skript eksisterer.. slet den lokale mappe $DIR"
	exit
fi
echo
echo "Tjekker om Git er installeret."
FILE=/usr/bin/git
REPO=https://github.com/Hvemmse/archinstalldanish
if [ -f "$FILE" ]; then
    echo
    echo "$FILE .. fundet"
    git clone $REPO
   
else 
    echo
    echo "$FILE Existerer ikke, installerer den nu ...."

FILE=git
 echo
 echo $FILE
	sudo pacman -S $FILE
	git clone $REPO
	
fi



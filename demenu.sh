#!/bin/bash
# 

clear
PS3='Choice your Desktop Enviroment: '
options=("Cinnamon" "Kde" "Gnome" "Qtile" "Xfce4" "Exit")
select opt in "${options[@]}"
do
    case $opt in
        "Cinnamon")
            echo "Cinnamon"
            ./cinnamon
            break
            ;;
        "Kde")
            echo "Kde"
            ./kde
            break
            ;;
        "Gnome")
            echo "$opt"
            ./gnome
            break
            ;;
        "Qtile")
            echo "$opt"
            ./qtile
            break
            ;;
        "Xfce4")
            echo "xfce"
            ./xfce4
			break
            ;;       
        "Exit")
            break
            ;;
        *) echo "This is not an Option $REPLY";;
    esac
done
